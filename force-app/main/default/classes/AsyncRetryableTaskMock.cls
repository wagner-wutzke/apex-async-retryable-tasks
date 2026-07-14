@isTest
public class AsyncRetryableTaskMock extends AbstractAsyncRetryableTask {
    //
    //
    public Boolean processCalled = false;
    public QueueableContext passedContext;

    public override void process(QueueableContext context) {
        this.processCalled = true;
        this.passedContext = context;

        // Simulating a scenario where a developer throws an error to test the catch handler
        if (this.parameters != null && this.parameters.containsKey('throwError')) {
            throw new AsyncRetryableTaskException('Simulated processing failure');
        }
    }

    public override String getIdempotencyKey() {
        return 'MockKey_12345';
    }
}
