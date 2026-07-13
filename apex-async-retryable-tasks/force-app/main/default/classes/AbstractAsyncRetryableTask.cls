public abstract class AbstractAsyncRetryableTask implements Queueable, Database.AllowsCallouts {
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
    public AsyncRetryableTask__c taskRecord { get; set; }
    public AsyncRetryableTaskConfiguration__mdt config { get; set; }

    public AbstractAsyncRetryableTask() {
    }

    public abstract void process();

    public abstract String getIdempotencyKey();

    /**
     * The execute() method will call the process() method in the concrete class.
     * The concrete class must implement a selective retry mechanism, depending on the error type.
     * For triggering a retry, it shall call handleFailure().
     */
    public void execute(QueueableContext context) {
        process();
    }

    /**
     * Delegates the error to the Task Manager for handling the failure
     * Check first if a retry really makes sense
     */
    public void handleError(Exception ex) {
        AsyncRetryableTaskManager.handleRetry(this, ex.getMessage());
    }

    public void finalizeTask(String status) {
        taskRecord.Status__c = status;
        taskRecord.ExecutionEndDatetime__c = Datetime.now();
        update taskRecord;
        AsyncRetryableTaskManager.createLog(taskRecord, status, 'Task finished with status: ' + status);
    }
}
