@isTest
public class AsyncRetryableTaskExceptionTest {
    //
    //
    @isTest
    static void testExceptionCoverage() {
        Boolean exceptionThrown = false;

        try {
            throw new AsyncRetryableTaskException('AsyncRetryableTaskException');
        } catch (AsyncRetryableTaskException ex) {
            exceptionThrown = true;
            System.Assert.areEqual('AsyncRetryableTaskException', ex.getMessage(), 'Exception message should match');
            Assert.areEqual('AsyncRetryableTaskException', ex.getMessage());
        }
        System.Assert.isTrue(exceptionThrown, 'The custom exception should have been caught');
    }
}
