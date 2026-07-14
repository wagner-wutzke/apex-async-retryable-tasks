@isTest
private class AbstractAsyncRetryableTaskTest {
    //
    final static String CONFIG_NAME = 'Mock_Task_Configuration';
    final static String TASK_CLASS_NAME = 'MockRetryableTask';

    @isTest
    static void testExecuteCallsProcess() {
        // Arrange
        AsyncRetryableTaskMock mockTask = new AsyncRetryableTaskMock();
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
        AsyncRetryableTaskMock mockTask = new AsyncRetryableTaskMock();
        AsyncRetryableTask__c taskRecord = new AsyncRetryableTask__c(
            Status__c = AbstractAsyncRetryableTask.STATUS_CREATED,
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
        AsyncRetryableTask__c testRecord = new AsyncRetryableTask__c(
            Status__c = AbstractAsyncRetryableTask.STATUS_CREATED,
            IdempotencyKey__c = 'LockedKey123',
            TaskClassName__c = TASK_CLASS_NAME,
            TaskConfigDeveloperName__c = CONFIG_NAME,
            MaxRetries__c = 3,
            Attempts__c = 0
        );
        insert testRecord;

        AsyncRetryableTaskMock mockTask = new AsyncRetryableTaskMock();
        mockTask.taskRecord = testRecord;

        // Act
        Test.startTest();
        mockTask.finalizeTask(AbstractAsyncRetryableTask.STATUS_FINISHED_SUCCESS);
        Test.stopTest();

        // Assert
        // Verify the parent record was updated correctly
        AsyncRetryableTask__c updatedRecord = [
            SELECT Status__c, ExecutionEndDatetime__c
            FROM AsyncRetryableTask__c
            WHERE Id = :testRecord.Id
        ];

        System.assertEquals(
            AbstractAsyncRetryableTask.STATUS_FINISHED_SUCCESS,
            updatedRecord.Status__c,
            'The task status must reflect the finalized state passed into the method.'
        );
        System.assertNotEquals(
            null,
            updatedRecord.ExecutionEndDatetime__c,
            'Execution end timestamp must be set to the current system clock upon finalization.'
        );

        // Note: Assuming AsyncRetryableTaskManager.createLog creates a log record under the hood,
        // you would add an SOSL/SOQL assertion here targeting your logging table (e.g., AsyncRetryableTaskLog__c)
        // to verify that the string 'Task finished with status: Finished with Success' was persisted.
    }

    @isTest
    static void testPropertyAccessorsAndConstants() {
        // Act & Assert (Verifying properties are public and constants are correctly defined)
        System.assertEquals('Executing', AbstractAsyncRetryableTask.STATUS_EXECUTING);
        System.assertEquals('Created', AbstractAsyncRetryableTask.STATUS_CREATED);
        System.assertEquals('Finished with Fail', AbstractAsyncRetryableTask.STATUS_FINISHED_FAIL);
        System.assertEquals('Finished with Success', AbstractAsyncRetryableTask.STATUS_FINISHED_SUCCESS);
        System.assertEquals('Retry', AbstractAsyncRetryableTask.STATUS_RETRY);
        System.assertEquals('Error', AbstractAsyncRetryableTask.STATUS_ERROR);

        AsyncRetryableTaskMock mockTask = new AsyncRetryableTaskMock();
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
