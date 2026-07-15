public with sharing class AsyncRetryableTaskManager {
    //
    //

    /**
     * 1. Create and returns a task instance of the configured value in
     * 'AsyncRetryableTaskConfiguration__mdt.TaskClassName__c' field.
     * 2. If the class cannot be found, a AsyncRetryableTaskException exception will be thrown.
     * 3. If the calculated idempotency key is already existent in any persisted record,
     *    a AsyncRetryableTaskException exception will be thrown.
     * 4. Persist a new AsyncRetryableTask__c record for holding the task status.
     * 5. Log the task creation.
     */
    public static AbstractAsyncRetryableTask createTask(
        AsyncRetryableTaskConfiguration__mdt taskConfig,
        Map<String, Object> parameters
    ) {
        AbstractAsyncRetryableTask concreteTaskInstance;

        // 1. Dinamically instantiate the concrete AbstractAsyncRetryableTask class.
        try {
            Type t = Type.forName(taskConfig.TaskClassName__c);
            concreteTaskInstance = (AbstractAsyncRetryableTask) t.newInstance();
            concreteTaskInstance.parameters = parameters;
            concreteTaskInstance.config = taskConfig;
        } catch (Exception ex) {
            throw new AsyncRetryableTaskException(
                'Error creating class instance for' + taskConfig.TaskClassName__c + ': ' + ex.getMessage()
            );
        }

        // 2. Get the idempotency key in the concrete class.
        // Each concrete class must have its implementation.
        String idempotencyKey = concreteTaskInstance.getIdempotencyKey();

        // 3. Idempotency Lock:
        // Verifies and blocks if there is an identical task key enqueued or executing.
        // If so, log it properly and abort the proccess.
        Boolean idempotencyCheckFailed = idempotencyKeyExists(idempotencyKey);
        if (idempotencyCheckFailed) {
            throw new AsyncRetryableTaskException('Task idempotency check hit. This task is already in execution.');
        }

        //4. Persists a new record for the concrete task
        AsyncRetryableTask__c taskRecord = createRecord(taskConfig, idempotencyKey, concreteTaskInstance);
        concreteTaskInstance.taskRecord = taskRecord;

        // 5. Log task creation
        createLog(taskRecord, AbstractAsyncRetryableTask.STATUS_CREATED, 'Task created.');
        return concreteTaskInstance;
    }

    /**
     * 1. Increment the number of attempts and updates the record.
     * 2. Enqueue the task with no delay (0), when it is the first attempt.
     * 3. Enqueue the task with apex system min. default queueable delay,
     *    when no delay parameter is given on the method call.
     *    > Setup > Apex Settings > Default minimum apex queueable delay (in seconds)
     */
    public static void enqueueTask(AbstractAsyncRetryableTask concreteTaskInstance) {
        if (concreteTaskInstance.taskRecord.Attempts__c == 0) {
            // TODO: check system governor limits before enqueueing!!!
            concreteTaskInstance.taskRecord.Attempts__c = 1;
            concreteTaskInstance.taskRecord.Status__c = AbstractAsyncRetryableTask.STATUS_EXECUTING;

            concreteTaskInstance.taskRecord.ApexJobId__c = System.enqueueJob(concreteTaskInstance, 0);
            update concreteTaskInstance.taskRecord;

            createLog(
                concreteTaskInstance.taskRecord,
                AbstractAsyncRetryableTask.STATUS_EXECUTING,
                'Task has been enqueued for the first time.'
            );
        } else {
            // TODO: check system governor limits before enqueueing!!!
            concreteTaskInstance.taskRecord.Attempts__c += 1;
            concreteTaskInstance.taskRecord.ApexJobId__c = System.enqueueJob(concreteTaskInstance);
            update concreteTaskInstance.taskRecord;
            createLog(
                concreteTaskInstance.taskRecord,
                AbstractAsyncRetryableTask.STATUS_RETRY,
                'Task enqueued for retry. Attempt no. ' + concreteTaskInstance.taskRecord.Attempts__c
            );
        }
    }

    /**
     * Verify if amount of retries has already reached the limit.
     * - If not: logs the error and enqueues the task again.
     * - Otherwise: logs the final step and finalizes the task.
     *              Task finalization is implemented by the concrete class.
     *
     */
    public static void handleRetry(AbstractAsyncRetryableTask concreteTaskInstance, String errorMessage) {
        AsyncRetryableTask__c taskRecord = concreteTaskInstance.taskRecord;

        Boolean isRetryableError = ErrorTypeEvaluator.evaluateErrorType(errorMessage);
        if (!isRetryableError) {
            concreteTaskInstance.taskRecord.Status__c = AbstractAsyncRetryableTask.STATUS_FINISHED_FAIL;
            concreteTaskInstance.finalizeTask(AbstractAsyncRetryableTask.STATUS_FINISHED_FAIL);
            createLog(
                concreteTaskInstance.taskRecord,
                AbstractAsyncRetryableTask.STATUS_FINISHED_FAIL,
                'Task aborted immediately. Non-retryable error encountered:\n' + errorMessage
            );
            return;
        }

        if (taskRecord.Attempts__c < taskRecord.MaxRetries__c + 1) {
            String logMsg = 'Execution failed. Scheduling retry... \nReason:\n' + errorMessage;
            createLog(taskRecord, AbstractAsyncRetryableTask.STATUS_ERROR, logMsg);
            enqueueTask(concreteTaskInstance);
        } else {
            // Max retries exhausted
            concreteTaskInstance.finalizeTask(AbstractAsyncRetryableTask.STATUS_FINISHED_FAIL);
            String logMsg = 'Task permanently failed. Max retry threshold reached.\nReason:\n' + errorMessage;
            createLog(taskRecord, AbstractAsyncRetryableTask.STATUS_FINISHED_FAIL, logMsg);
        }
    }

    /**
     * Create a log record and a debug output.
     * The logging procedure could also be plsced in the concerete task.
     * Following KISS principle, we do it here.
     */
    public static void createLog(AsyncRetryableTask__c taskRecord, String status, String message) {
        AsyncRetryableTaskLog__c log = new AsyncRetryableTaskLog__c();
        log.AsyncRetryableTask__c = taskRecord.Id;
        log.LogMessage__c = message != null && message.length() > 4096 ? message.substring(0, 4092) + '...' : message;
        log.Status__c = status;
        log.Attempt__c = taskRecord.Attempts__c;
        log.SerializedTaskRecord__c = JSON.serializePretty(taskRecord);
        insert log;
        System.debug(LoggingLevel.DEBUG, message);
    }

    /**
     * Check if the idempotency key is present among the executing records.
     */
    @TestVisible
    private static Boolean idempotencyKeyExists(String idempotencyKey) {
        List<AsyncRetryableTask__c> existingTasks = [
            SELECT Id, Status__c
            FROM AsyncRetryableTask__c
            WHERE
                IdempotencyKey__c = :idempotencyKey
                AND (Status__c = :AbstractAsyncRetryableTask.STATUS_CREATED
                OR Status__c = :AbstractAsyncRetryableTask.STATUS_EXECUTING)
            LIMIT 1
            FOR UPDATE
        ];
        return !existingTasks.isEmpty();
    }

    @TestVisible
    private static AsyncRetryableTask__c createRecord(
        AsyncRetryableTaskConfiguration__mdt config,
        String idempotencyKey,
        AbstractAsyncRetryableTask concreteTaskInstance
    ) {
        AsyncRetryableTask__c taskRecord = new AsyncRetryableTask__c();
        taskRecord.MaxRetries__c = config.MaxRetries__c;
        taskRecord.Attempts__c = 0;
        taskRecord.Status__c = AbstractAsyncRetryableTask.STATUS_CREATED;
        taskRecord.TaskClassName__c = config.TaskClassName__c;
        taskRecord.IdempotencyKey__c = idempotencyKey;
        taskRecord.ExecutionStartDateTime__c = Datetime.now();
        taskRecord.SerializedParameters__c = JSON.serialize(concreteTaskInstance.parameters);
        taskRecord.TaskConfigDeveloperName__c = config.DeveloperName;
        insert taskRecord;
        return taskRecord;
    }
}
