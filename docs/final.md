# Drawbacks, enhancements, final words

In this chapter I would like to say some words about the current framework implementation. Specifically regarding the questions:

- what could be enhanced?
- what could perhaps be done differently?
- which issues were found during implementation?

## Error Type Evaluator

The `ErrorTypeEvaluator` class implements the the error message evaluation of the exception catched during the task execution.\
In the current solution, the evaluation happens over 2 sets of regular expressions: one for non-retryable errors `NON_RETRYABLE_PATTERN` and another for retriable errors `RETRYABLE_PATTERN`.\
It works well this way, but what if one wants to add an new message to one of the patterns? It would be necessary to change the class, enhance its tests and re-deploy. This is not configurable at all and has a big enhancement potential.\
**This is a big Drawback.**\
In order to fix this issue, I would suggest to store the data to be configured - in this case, the error messages excerpts - in a new Custom Metadata Type. This is a Salesforce Best Practice.\
The implementation would be as follows:

- Create a new Custom Metadata Type named `Retryable_Task_Error_Filter_mdt` with following custom fields:
    - Match_Phrase__c (Text, 255)
    - Is_Retryable__c (Checkbox, default(True))
    - Active__c (Checkbox, default(True))

The new `ErrorTypeEvaluator` implementation would look like this:

```java
public class ErrorTypeEvaluator {

    @TestVisible
    private static Boolean evaluateErrorType(String errorMessage) {
        if (String.isBlank(errorMessage)) {
            return false;
        }
        String lowerMessage = errorMessage.toLowerCase();

        // Hardcoded special case rule remains first
        if (lowerMessage.contains('unhandled_trigger_exception') &&
            lowerMessage.contains('lock deadlocks')) {
            return true;
        }

        List<Error_Filter__mdt> filters = Error_Filter__mdt.getAll().values();

        // Separate lists to enforce precedence (Non-retryable must check first)
        for (Error_Filter__mdt filter : filters) {
            if (!filter.Is_Retryable__c && filter.Active__c &&
                lowerMessage.contains(filter.Match_Phrase__c.toLowerCase())) {
                return false;
            }
        }

        for (Error_Filter__mdt filter : filters) {
            if (filter.Is_Retryable__c && filter.Active__c &&
                lowerMessage.contains(filter.Match_Phrase__c.toLowerCase())) {
                return true;
            }
        }
        return true;
    }
}
```

Why using CMDT is better?

- **Zero-Code Updates**: Admins or devs can add new error types in production via Setup without running tests or deployments.
- **Blazing Fast**: getAll() reads from Salesforce's application cache, consuming virtually no CPU time or limits.

<br>

With this implementation every possible error message is a new record of the `Retryable_Task_Error_Filter_mdt`.\
New ones can be easily added and old ones can be deactivated or deleted, without changing the code.
<br><br>

## Transaction Finalizer as alternative for Retry

> _With transaction finalizers, you can attach a post-action sequence to a Queueable job and take relevant actions based on the job execution result.
> A Queueable job that failed due to an unhandled exception can be successively re-enqueued five times by a transaction finalizer. This limit applies to a series of consecutive Queueable job failures. The counter is reset when the Queueable job completes without an unhandled exception._

Source: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_transaction_finalizers.htm

Using a Transaction Finalizer, the retry implementation responsibility could be transfered to a new class implementing the `Finalizer` interface.
This would look like this:

```java
public class MyTaskFinalizer implements Finalizer {
    public void execute(FinalizerContext ctx) {
        // evaluate error
        // check if retry max attempts has been reached
        // log relevant information
        // enqueue task
        if (ctx.getResult() == ParentJobResult.SUCCESS) {
            System.debug('Parent queueable task [' + parentJobId + '] completed successfully.');
        } else {
            System.debug('Enqueueing another instance of the queueable...');
        }
    }
}

// adjust the AbstractRetryableTask execute method
public abstract class AbstractRetryableTask ... {
    ...
    public void execute(QueueableContext context) {
        try {
            System.attachFinalizer(new MyTaskFinalizer());
            process(context);
            finalizeTask(STATUS_FINISHED_SUCCESS, 'Task finished with status: ' + STATUS_FINISHED_SUCCESS);
        } catch (Exception ex) {
                handleError(ex);
        }
    }
}
```

<br>

## System Queue & Governor Limits

Yes, I forgot one very important point when implementing this framework.
I do not check if the Salesforce System Job Queue is getting overloaded when adding new jobs to it. **This is a huge drawback 🤦‍♂️.**\
But this is very easy to fix.\
One question though, still remains: _what do we do with the tasks that cannot be enqueued due to system queue overload?_\
My first intuition would be to redirect those tasks to a Dead-Letter Queue and log it properly.
Additionally, perhaps would be thoughtful to not use the whole System Queue Governor Queue Size Limit (50) for this framework alone, but take perhaps 80% only.

This is what needs to be added to the `RetryableTaskManager.enqueueTask()` method.

```java
Integer limit = Integer.valueOf(Limits.getLimitQueueableJobs() * 0.8);
Integer availableJobs = limit - Limits.getQueueableJobs();
if (availableJobs > 0) {
    System.enqueueJob(new MyQueueableJob());
}
else {
    // Dead-Letter Queue if System Queue limit reached?
    RetryableTaskManager.toDeadLetterQueue(concreteTaskInstance);
}
```

<br>

## Dead Letter Queue

### Architectural Blueprint

```
[ Queueable Job ] ──(Transient Error)──> [ Finalizer ] ──> [ Schedulable (Delay) ] ──> [ Next Queueable ]
       │                                     │
 (Fatal Error)                       (Max Retries Hit)
       │                                     │
       ▼                                     ▼
[ Log to DLQ ] <─────────────────────────────┘
```

The main idea of a Dead-Letter Queue in this context is to have a place to store undeliverable or failed asynchronous tasks.\ This can happen when:

- The Queue size limit has been reached.
- The amount of max retries has been reached.

Since Salesforce does not provide an out-of-the-box DLQ for Apex or standard Platform Events, developers typically implement a custom DLQ mechanism to prevent data loss.

In order to use the DLQ, the `RetryableTaskManager.handleRetry()` method must be adjusted.

```java
} else {
    // Max retries exhausted
    String logMsg = 'Task permanently failed. Max retry threshold reached.\nReason:\n' + errorMessage;
    Failed_Task__c failedTask = new Failed_Task__c();
    // set the record fields accordingly
    insert failedTask;
    concreteTaskInstance.finalizeTask(AbstractRetryableTask.STATUS_FINISHED_FAIL, logMsg);
}
```

After saving the Dead-Letter record, maybe sending a notification to an administrator over Slack, Teams or something similar could make sense.
<br>

## Exponential Backoff Delay

The current implementation does not use an Exponential Backoff Delay.
This is because I was willing to work with delays in the range of seconds.
Salesforce System.enqueue(task, min) method works unfortuantely with minutes.\
So I changed the default Minimum Apex Queueable Delay setting to 30 secs and work with that same delay on each retry.\

> Setup > Apex Settings > Default minimum apex queueable delay

Of course, I could use a Scheduler for scheduling the task retry enqueueing.\
But this would be out of this experiment's scope.
<br>

## Final Words

This was the last article on this series of three.\
It is astonishing how one little topic can bring so much to the table.

I hope, the ideas brought here can be helpful.
Feel free to have a look in the source code and comment.
The articles are also in my [Wordpress blog](https://wagnerwutzke.wordpress.com/).

The source code, ApexDox docs, anonymous Apex script and example classes are in my projects [repository](https://github.com/wagner-wutzke/apex-async-retryable-tasks) on GitHub.<br>

<br>

[<< BACK](../README.md)
