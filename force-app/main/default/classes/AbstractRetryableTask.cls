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

    public abstract void process(QueueableContext context);

    public abstract String getIdempotencyKey();

    /**
     * The execute() method will call the process() method in the concrete class.
     * The concrete class must implement a selective retry mechanism, depending on the error type.
     * For triggering a retry, it shall call handleEror().
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
     * Delegates the error to the Task Manager for handling the failure
     * Check first if a retry really makes sense
     */
    public void handleError(Exception ex) {
        RetryableTaskManager.handleRetry(this, ex.getMessage());
    }

    public void finalizeTask(String status, String message) {
        taskRecord.Status__c = status;
        taskRecord.ExecutionEndDatetime__c = Datetime.now();
        update taskRecord;
        RetryableTaskManager.createLog(taskRecord, status, message);
    }
}
