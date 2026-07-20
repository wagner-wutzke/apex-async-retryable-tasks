/**
 * @description The `AbstractRetryableTask` class defines the base functionality for a retryable task,
 * along with the skeleton methods to be implemented by the extending concrete task classes.
 * of retryable queueable tasks (tasks extending the `AbstractRetryTask` class)
 *
 * @group apex-async-retriable-tasks
 * @author Wagner O. Wutzke - wagner.wutzke@gmail.com
 *
 */

public abstract class AbstractRetryableTask implements Queueable, Database.AllowsCallouts {
    //
    //
    public static final String STATUS_EXECUTING = 'Executing';
    public static final String STATUS_CREATED = 'Created';
    public static final String STATUS_FINISHED_FAIL = 'Finished with Fail';
    public static final String STATUS_FINISHED_SUCCESS = 'Finished with Success';
    public static final String STATUS_RETRY = 'Retry';
    public static final String STATUS_ERROR = 'Error';

    public Map<String, Object> parameters { get; set; }
    public String configDeveloperName { get; set; }
    public RetryableTask__c taskRecord { get; set; }
    public RetryableTaskConfiguration__mdt config { get; set; }

    public AbstractRetryableTask() {
    }

    /**
     * @description implements the real logic to be executed when running the queueable job.
     * @param context the queuable context
     * @return  `abstract void`
     */
    public abstract void process(QueueableContext context);

    /**
     * @description The concrete class implementes how to calculate an unique idempotency key and returns it.
     * @return the calculated idempotency key
     */
    public abstract String getIdempotencyKey();

    /**
     * The execute() method will call the process() method in the concrete class.<br>
     * The concrete class must implement a selective retry mechanism, depending on the error type.<br>
     * For triggering a retry, it shall call handleEror().
     * @param context the queuable context
     */
    public void execute(QueueableContext context) {
        try {
            process(context);
            finalizeTask(STATUS_FINISHED_SUCCESS, 'Task finished with status: ' + STATUS_FINISHED_SUCCESS);
        } catch (Exception ex) {
            handleError(ex);
        }
    }

    /**
     * @description Delegates the error to the Task Manager for handling the failure.
     * @param ex the exception to be evaluated.
     */
    public void handleError(Exception ex) {
        RetryableTaskManager.handleRetry(this, ex.getMessage());
    }

    /**
     * @description
     * @param status final status to be set.
     * @param message the message for logging when finishing.
     */
    public void finalizeTask(String status, String message) {
        taskRecord.Status__c = status;
        taskRecord.ExecutionEndDatetime__c = Datetime.now();
        update taskRecord;
        RetryableTaskManager.createLog(taskRecord, status, message);
    }
}