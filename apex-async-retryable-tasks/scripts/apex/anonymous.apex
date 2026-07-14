AsyncRetryableTaskLog__c[] logs = [SELECT ID FROM AsyncRetryableTaskLog__c];
delete logs;

AsyncRetryableTask__c[] tasks = [SELECT ID FROM AsyncRetryableTask__c];
delete tasks;

AbstractAsyncRetryableTask concreteTaskInstance;

final static String IDEMTPOTENCY_KEY = 'idempotency_key';
final static String CONFIG_NAME = 'Mock_Task_Configuration';
final static String TASK_CLASS_NAME = 'ExampleAsyncRetryableTask';

Map<String, Object> fieldMap = new Map<String, Object>{
    'DeveloperName' => 'Example_Task',
    'MasterLabel' => 'Example_Task',
    'TaskClassName__c' => 'CalloutAsyncRetryableTask',
    'MaxRetries__c' => 3
};
AsyncRetryableTaskConfiguration__mdt config = (AsyncRetryableTaskConfiguration__mdt) JSON.deserialize(
    JSON.serialize(fieldMap),
    AsyncRetryableTaskConfiguration__mdt.class
);

// 504 Gateway Timeout - Retryable
try {
    concreteTaskInstance = AsyncRetryableTaskManager.createTask(
        config,
        new Map<String, Object>{ 'callout_url' => 'https://httpstat.us/504', 'idempotency_key' => 123456 }
    );
    AsyncRetryableTaskManager.enqueueTask(concreteTaskInstance);
} catch (AsyncRetryableTaskException ex) {
    System.debug(LoggingLevel.ERROR, ex.getMessage());
}

// 503 Service Unavailable - Non-Retryable
try {
    concreteTaskInstance = AsyncRetryableTaskManager.createTask(
        config,
        new Map<String, Object>{ 'callout_url' => 'https://httpstat.us/503', 'idempotency_key' => 666666 }
    );
    AsyncRetryableTaskManager.enqueueTask(concreteTaskInstance);
} catch (AsyncRetryableTaskException ex) {
    System.debug(LoggingLevel.ERROR, ex.getMessage());
}

// 200 OK
try {
    concreteTaskInstance = AsyncRetryableTaskManager.createTask(
        config,
        new Map<String, Object>{ 'callout_url' => 'https://www.google.com', 'idempotency_key' => 999999 }
    );
    AsyncRetryableTaskManager.enqueueTask(concreteTaskInstance);
} catch (AsyncRetryableTaskException ex) {
    System.debug(LoggingLevel.ERROR, ex.getMessage());
}
