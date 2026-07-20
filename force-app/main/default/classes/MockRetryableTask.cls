/**
 * @description This class is used for testing purposes in the the `TaskManagerTest` class.
 *
 * @group test
 * @author Wagner O. Wutzke - wagner.wutzke@gmail.com
 *
 */

@isTest
public class MockRetryableTask extends AbstractRetryableTask {
    //
    //
    public Boolean processCalled = false;
    public QueueableContext passedContext;

    public override void process(QueueableContext context) {
        this.processCalled = true;
        this.passedContext = context;

        // Simulating a scenario where a developer throws an error to test the catch handler
        if (this.parameters != null && this.parameters.containsKey('throwError')) {
            throw new RetryableTaskException('Simulated processing failure');
        }
    }

    public override String getIdempotencyKey() {
        return 'MockKey_12345';
    }
}