RetryableTaskLog__c[] logs = [SELECT ID FROM RetryableTaskLog__c];
delete logs;

RetryableTask__c[] tasks = [SELECT ID FROM RetryableTask__c];
delete tasks;

ConnectApi.NamedCredential namedCredential_200 = ConnectApi.NamedCredentials.getNamedCredential('STATUS_200_OK');
ConnectApi.NamedCredential namedCredential_403 = ConnectApi.NamedCredentials.getNamedCredential(
    'STATUS_403_Unrecoverable'
);
ConnectApi.NamedCredential namedCredential_503 = ConnectApi.NamedCredentials.getNamedCredential(
    'STATUS_503_Recoverable'
);

RetryableTaskConfiguration__mdt config = RetryableTaskConfiguration__mdt.getInstance('CalloutRetryableTask');

// this task will succeed after first execution
AbstractRetryableTask task_200 = RetryableTaskManager.createTask(
    config,
    new Map<String, Object>{ 'idempotency_key' => 333333, 'named_credential' => namedCredential_200.developerName }
);
RetryableTaskManager.enqueueTask(task_200);

// this task will fail after first execution and be finished due
// to unrecoverable failure - 403 - Forbidden
AbstractRetryableTask task_403 = RetryableTaskManager.createTask(
    config,
    new Map<String, Object>{ 'idempotency_key' => 666666, 'named_credential' => namedCredential_403.developerName }
);
RetryableTaskManager.enqueueTask(task_403);

// this task will fail after first execution and be rescheduled for retry
// 503 - Service Unavailable
AbstractRetryableTask task_503 = RetryableTaskManager.createTask(
    config,
    new Map<String, Object>{ 'idempotency_key' => 999999, 'named_credential' => namedCredential_503.developerName }
);
RetryableTaskManager.enqueueTask(task_503);
