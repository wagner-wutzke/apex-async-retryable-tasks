/**
 * @description
 *
 * @group test
 * @author Wagner O. Wutzke - wagner.wutzke@gmail.com
 *
 */
@isTest
public class RetryableTaskExceptionTest {
    //
    //
    @isTest
    static void testExceptionCoverage() {
        Boolean exceptionThrown = false;

        try {
            throw new RetryableTaskException('RetryableTaskException');
        } catch (RetryableTaskException ex) {
            exceptionThrown = true;
            System.Assert.areEqual('RetryableTaskException', ex.getMessage(), 'Exception message should match');
            Assert.areEqual('RetryableTaskException', ex.getMessage());
        }
        System.Assert.isTrue(exceptionThrown, 'The custom exception should have been caught');
    }
}
