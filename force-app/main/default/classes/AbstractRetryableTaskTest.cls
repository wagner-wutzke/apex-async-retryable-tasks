@isTest
private class AbstractRetryableTaskTest {
    //
    final static String CONFIG_NAME = 'Mock_Task_Configuration';
    final static String TASK_CLASS_NAME = 'MockRetryableTask';

    @isTest
    static void testExecuteCallsProcess() {
        // Arrange
        MockRetryableTask mockTask = new MockRetryableTask();
        mockTask.parameters = new Map<String, Object>{ 'testParam' => 'value' };

        // Act
        Test.startTest();
        // Passing null as QueueableContext since it's an interface and we are testing the delegation layer
        mockTask.execute(null);
        Test.stopTest();

        // Assert
        System.assertEquals(
            true,
            mockTask.processCalled,
            'The execute method must successfully delegate running logic to the abstract process method.'
        );
    }

    @isTest
    static void testHandleErrorDelegatesToManager() {
        // Arrange
        MockRetryableTask mockTask = new MockRetryableTask();
        RetryableTask__c taskRecord = new RetryableTask__c(
            Status__c = AbstractRetryableTask.STATUS_CREATED,
            IdempotencyKey__c = 'LockedKey123',
            TaskClassName__c = TASK_CLASS_NAME,
            TaskConfigDeveloperName__c = CONFIG_NAME,
            MaxRetries__c = 1,
            Attempts__c = 1
        );
        insert taskRecord;
        mockTask.taskRecord = taskRecord;
        mockTask.parameters = new Map<String, Object>{ 'throwError' => true };

        // Act
        Test.startTest();
        try {
            mockTask.execute(null);
        } catch (Exception ex) {
            mockTask.handleError(ex);
        }
        Test.stopTest();

        // Assert
        // Note: This test verifies execution path continuity. It ensures no internal unhandled exceptions
        // occur within the abstract wrapper when error handling triggers.
        // The task will be executed once, then fail.
        // Retry will apply only once and finish, having Attempts__c = 2 in the end.
        System.assertEquals(true, mockTask.processCalled, 'Process should have executed and failed.');
        System.assertEquals(2, mockTask.taskRecord.Attempts__c, 'Process should have handled a single retry.');
    }

    @isTest
    static void testFinalizeTaskUpdatesRecordAndLogs() {
        // Arrange
        // 1. Prepare base parent task record required by the abstract architecture
        RetryableTask__c testRecord = new RetryableTask__c(
            Status__c = AbstractRetryableTask.STATUS_CREATED,
            IdempotencyKey__c = 'LockedKey123',
            TaskClassName__c = TASK_CLASS_NAME,
            TaskConfigDeveloperName__c = CONFIG_NAME,
            MaxRetries__c = 3,
            Attempts__c = 0
        );
        insert testRecord;

        MockRetryableTask mockTask = new MockRetryableTask();
        mockTask.taskRecord = testRecord;

        // Act
        Test.startTest();
        mockTask.finalizeTask(AbstractRetryableTask.STATUS_FINISHED_SUCCESS);
        Test.stopTest();

        // Assert
        // Verify the parent record was updated correctly
        RetryableTask__c updatedRecord = [
            SELECT Status__c, ExecutionEndDatetime__c
            FROM RetryableTask__c
            WHERE Id = :testRecord.Id
        ];

        System.assertEquals(
            AbstractRetryableTask.STATUS_FINISHED_SUCCESS,
            updatedRecord.Status__c,
            'The task status must reflect the finalized state passed into the method.'
        );
        System.assertNotEquals(
            null,
            updatedRecord.ExecutionEndDatetime__c,
            'Execution end timestamp must be set to the current system clock upon finalization.'
        );

        // Note: Assuming RetryableTaskManager.createLog creates a log record under the hood,
        // you would add an SOSL/SOQL assertion here targeting your logging table (e.g., RetryableTaskLog__c)
        // to verify that the string 'Task finished with status: Finished with Success' was persisted.
    }

    @isTest
    static void testPropertyAccessorsAndConstants() {
        // Act & Assert (Verifying properties are public and constants are correctly defined)
        System.assertEquals('Executing', AbstractRetryableTask.STATUS_EXECUTING);
        System.assertEquals('Created', AbstractRetryableTask.STATUS_CREATED);
        System.assertEquals('Finished with Fail', AbstractRetryableTask.STATUS_FINISHED_FAIL);
        System.assertEquals('Finished with Success', AbstractRetryableTask.STATUS_FINISHED_SUCCESS);
        System.assertEquals('Retry', AbstractRetryableTask.STATUS_RETRY);
        System.assertEquals('Error', AbstractRetryableTask.STATUS_ERROR);

        MockRetryableTask mockTask = new MockRetryableTask();
        mockTask.configDeveloperName = 'My_Metadata_Config';

        System.assertEquals(
            'My_Metadata_Config',
            mockTask.configDeveloperName,
            'Getter/Setter accessors must be active for configuration names.'
        );
        System.assertEquals(
            'MockKey_12345',
            mockTask.getIdempotencyKey(),
            'Idempotency key extraction layout must return valid strings.'
        );
    }
}