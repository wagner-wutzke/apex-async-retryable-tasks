@isTest
public class AsyncRetryableTaskManagerTest {
    //
    //
    final static String IDEMTPOTENCY_KEY = 'idempotency_key';
    final static String CONFIG_NAME = 'Mock_Task_Configuration';
    final static String TASK_CLASS_NAME = 'MockRetryableTask';

    final static AsyncRetryableTaskConfiguration__mdt mockConfigMdt = createMockConfigCMDT(
        CONFIG_NAME,
        TASK_CLASS_NAME,
        3
    );

    private static AsyncRetryableTaskConfiguration__mdt createMockConfigCMDT(
        String devName,
        String className,
        Decimal maxRetries
    ) {
        Map<String, Object> fieldMap = new Map<String, Object>{
            'DeveloperName' => devName,
            'MasterLabel' => devName,
            'TaskClassName__c' => className,
            'MaxRetries__c' => maxRetries
        };
        return (AsyncRetryableTaskConfiguration__mdt) JSON.deserialize(
            JSON.serialize(fieldMap),
            AsyncRetryableTaskConfiguration__mdt.class
        );
    }

    @isTest
    static void testCreateTaskSuccess() {
        // Setup parameters
        Map<String, Object> params = new Map<String, Object>{ IDEMTPOTENCY_KEY => 'UniqueKey123' };

        Test.startTest();
        AbstractAsyncRetryableTask resultTask = AsyncRetryableTaskManager.createTask(mockConfigMdt, params);
        Test.stopTest();

        System.assertNotEquals(null, resultTask, 'Task instance should be created.');
        System.assertEquals('UniqueKey123', resultTask.getIdempotencyKey());
        System.assertNotEquals(null, resultTask.taskRecord.Id, 'Task record should be persisted.');

        // Verify Log Creation
        List<AsyncRetryableTaskLog__c> logs = [SELECT Id, Status__c FROM AsyncRetryableTaskLog__c];
        System.assertEquals(1, logs.size());
        System.assertEquals('Created', logs[0].Status__c);
    }

    @isTest
    static void testCreateTaskWithInexistentClass() {
        // Setup parameters
        Map<String, Object> params = new Map<String, Object>{ IDEMTPOTENCY_KEY => 'UniqueKey123' };

        Test.startTest();
        AbstractAsyncRetryableTask resultTask;
        mockConfigMdt.TaskClassName__c = 'SomeRandomClassName';
        try {
            resultTask = AsyncRetryableTaskManager.createTask(mockConfigMdt, params);
        } catch (Exception ex) {
            System.assert(
                ex.getMessage().contains('Error creating class instance for' + mockConfigMdt.TaskClassName__c),
                'Should not be able to find the class for instantiation'
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateTaskIdempotencyLockHit() {
        // Create an existing active record to trigger the lock
        AsyncRetryableTask__c existingTask = new AsyncRetryableTask__c(
            IdempotencyKey__c = 'LockedKey123',
            TaskClassName__c = TASK_CLASS_NAME,
            MaxRetries__c = 3,
            TaskConfigDeveloperName__c = CONFIG_NAME,
            Status__c = AbstractAsyncRetryableTask.STATUS_CREATED,
            Attempts__c = 0
        );
        insert existingTask;

        Test.startTest();
        Boolean lockDetected = AsyncRetryableTaskManager.idempotencyKeyExists('LockedKey123');
        Test.stopTest();

        System.assertEquals(true, lockDetected, 'Idempotency check should find the duplicate record.');
    }

    @isTest
    static void testEnqueueTaskFirstAttempt() {
        // Setup initial task record state
        AsyncRetryableTask__c record = new AsyncRetryableTask__c(
            IdempotencyKey__c = 'LockedKey123',
            TaskClassName__c = TASK_CLASS_NAME,
            MaxRetries__c = 3,
            TaskConfigDeveloperName__c = CONFIG_NAME,
            Status__c = AbstractAsyncRetryableTask.STATUS_CREATED,
            Attempts__c = 0
        );
        insert record;

        MockRetryableTask mockTask = new MockRetryableTask();
        mockTask.taskRecord = record;

        Test.startTest();
        AsyncRetryableTaskManager.enqueueTask(mockTask);
        Test.stopTest();

        // Reload record from DB
        AsyncRetryableTask__c updatedRecord = [
            SELECT Attempts__c, Status__c, ApexJobId__c
            FROM AsyncRetryableTask__c
            WHERE Id = :record.Id
        ];
        System.assertEquals(1, updatedRecord.Attempts__c, 'Attempts should increment to 1.');
        System.assertEquals('Executing', updatedRecord.Status__c);
        System.assertNotEquals(null, updatedRecord.ApexJobId__c, 'Apex Job ID should be populated.');
    }

    @isTest
    static void testEnqueueTaskRetryAttempt() {
        AsyncRetryableTask__c record = new AsyncRetryableTask__c(
            IdempotencyKey__c = 'LockedKey123',
            TaskClassName__c = TASK_CLASS_NAME,
            MaxRetries__c = 3,
            TaskConfigDeveloperName__c = CONFIG_NAME,
            Status__c = AbstractAsyncRetryableTask.STATUS_EXECUTING,
            Attempts__c = 1
        );
        insert record;

        MockRetryableTask mockTask = new MockRetryableTask();
        mockTask.taskRecord = record;

        Test.startTest();
        AsyncRetryableTaskManager.enqueueTask(mockTask);
        Test.stopTest();

        AsyncRetryableTask__c updatedRecord = [
            SELECT Attempts__c, ApexJobId__c
            FROM AsyncRetryableTask__c
            WHERE Id = :record.Id
        ];
        System.assertEquals(2, updatedRecord.Attempts__c, 'Attempts should increment to 2.');
        System.assertNotEquals(null, updatedRecord.ApexJobId__c);
    }

    @isTest
    static void testHandleRetryWithinThreshold() {
        AsyncRetryableTask__c record = new AsyncRetryableTask__c(
            Attempts__c = 1,
            MaxRetries__c = 3,
            IdempotencyKey__c = 'LockedKey123',
            TaskClassName__c = TASK_CLASS_NAME,
            TaskConfigDeveloperName__c = CONFIG_NAME,
            Status__c = AbstractAsyncRetryableTask.STATUS_EXECUTING
        );
        insert record;

        MockRetryableTask mockTask = new MockRetryableTask();
        mockTask.taskRecord = record;

        Test.startTest();
        AsyncRetryableTaskManager.handleRetry(mockTask, 'Mock error text');
        Test.stopTest();

        AsyncRetryableTask__c updatedRecord = [SELECT Attempts__c FROM AsyncRetryableTask__c WHERE Id = :record.Id];
        System.assertEquals(2, updatedRecord.Attempts__c, 'Task should re-enqueue and increase attempt count.');
    }

    @isTest
    static void testHandleRetryMaxThresholdReached() {
        AsyncRetryableTask__c record = new AsyncRetryableTask__c(
            Attempts__c = 4, // Exceeds MaxRetries + 1 (3 + 1 = 4)
            MaxRetries__c = 3,
            IdempotencyKey__c = 'LockedKey123',
            TaskClassName__c = TASK_CLASS_NAME,
            TaskConfigDeveloperName__c = CONFIG_NAME,
            Status__c = AbstractAsyncRetryableTask.STATUS_EXECUTING
        );
        insert record;

        MockRetryableTask mockTask = new MockRetryableTask();
        mockTask.taskRecord = record;

        Test.startTest();
        AsyncRetryableTaskManager.handleRetry(mockTask, 'Fatal error');
        Test.stopTest();

        List<AsyncRetryableTaskLog__c> logs = [
            SELECT Status__c, LogMessage__c
            FROM AsyncRetryableTaskLog__c
            WHERE AsyncRetryableTask__c = :record.Id
        ];
        System.assertEquals(
            AbstractAsyncRetryableTask.STATUS_FINISHED_FAIL,
            mockTask.taskRecord.Status__c,
            'Concrete implementation should be set to Failed status.'
        );
        System.assertEquals(
            AbstractAsyncRetryableTask.STATUS_FINISHED_FAIL,
            logs[0].Status__c,
            'Log status should represent permanent failure.'
        );
    }

    @isTest
    static void testCreateLogStringTrimming() {
        AsyncRetryableTask__c record = new AsyncRetryableTask__c(
            Attempts__c = 1,
            IdempotencyKey__c = 'LockedKey123',
            TaskClassName__c = TASK_CLASS_NAME,
            TaskConfigDeveloperName__c = CONFIG_NAME,
            MaxRetries__c = 3,
            Status__c = AbstractAsyncRetryableTask.STATUS_EXECUTING
        );
        insert record;

        // Create a string longer than 4096 characters
        String longMessage = 'A'.repeat(5000);

        Test.startTest();
        AsyncRetryableTaskManager.createLog(record, 'Error', longMessage);
        Test.stopTest();

        AsyncRetryableTaskLog__c log = [
            SELECT LogMessage__c
            FROM AsyncRetryableTaskLog__c
            WHERE AsyncRetryableTask__c = :record.Id
            LIMIT 1
        ];
        System.assertEquals(
            4095,
            log.LogMessage__c.length(),
            'Message should be safely substringed down with appended ellipses.'
        );
        System.assert(log.LogMessage__c.endsWith('...'));
    }

    @isTest
    static void testHandleNonRetryableError() {
        AsyncRetryableTask__c record = new AsyncRetryableTask__c(
            Attempts__c = 1,
            MaxRetries__c = 3,
            IdempotencyKey__c = 'LockedKey123',
            TaskClassName__c = TASK_CLASS_NAME,
            TaskConfigDeveloperName__c = CONFIG_NAME,
            Status__c = AbstractAsyncRetryableTask.STATUS_EXECUTING
        );
        insert record;

        MockRetryableTask mockTask = new MockRetryableTask();
        mockTask.taskRecord = record;

        Test.startTest();
        AsyncRetryableTaskManager.handleRetry(mockTask, 'Unauthorized Access');
        Test.stopTest();

        AsyncRetryableTask__c updatedRecord = [
            SELECT Attempts__c, Status__c
            FROM AsyncRetryableTask__c
            WHERE Id = :record.Id
        ];
        System.assertEquals(1, updatedRecord.Attempts__c, 'Task should be gracefully finished.');
        System.assertEquals(
            AbstractAsyncRetryableTask.STATUS_FINISHED_FAIL,
            updatedRecord.Status__c,
            'Task should be gracefully finished.'
        );
    }
}
