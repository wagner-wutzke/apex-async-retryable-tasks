@IsTest
private class ErrorTypeEvaluatorTest {
    @IsTest
    static void testEvaluateErrorType_BlankAndNull() {
        // Assert that null or blank messages return false
        System.Assert.isFalse(ErrorTypeEvaluator.evaluateErrorType(null), 'Null messages should return false');
        System.Assert.isFalse(ErrorTypeEvaluator.evaluateErrorType(''), 'Empty strings should return false');
        System.Assert.isFalse(ErrorTypeEvaluator.evaluateErrorType('   '), 'Whitespace strings should return false');
    }

    @IsTest
    static void testEvaluateErrorType_NonRetryableRegexMatches() {
        // Prepare variations matching each phrase in the non-retryable regex pattern
        List<String> nonRetryableErrors = new List<String>{
            'FATAL_ERROR: required_field_missing on account name',
            'Exception: field_custom_validation_exception occurred',
            'string_too_long: text exceeds max length allowed',
            'Received a bad request error from endpoint',
            'Error: unauthorized access to resource',
            'This action is forbidden for your user profile',
            'System.NullPointerException: Attempt to de-reference a null object',
            'invalid_field on contact mapping lookup'
        };

        // Assert all non-retryable inputs return false across mixed case testing
        for (String errMsg : nonRetryableErrors) {
            System.Assert.isFalse(ErrorTypeEvaluator.evaluateErrorType(errMsg), 'Should not retry: ' + errMsg);
            System.Assert.isFalse(
                ErrorTypeEvaluator.evaluateErrorType(errMsg.toUpperCase()),
                'Should not retry (uppercase): ' + errMsg
            );
        }
    }

    @IsTest
    static void testEvaluateErrorType_RetryableRegexMatches() {
        // Prepare variations matching each phrase in the retryable regex pattern
        List<String> retryableErrors = new List<String>{
            'System.CalloutException: read timed out after 120s',
            'Web service connection timed out during execution',
            'Execution abandoned due to callout loop detection',
            'too many requests - HTTP rate limit hit',
            'Remote server threw internal server error',
            'service unavailable status returned from api',
            'gateway timeout occurred on the edge proxy'
        };

        // Assert all retryable inputs return true across mixed case testing
        for (String errMsg : retryableErrors) {
            System.Assert.isTrue(ErrorTypeEvaluator.evaluateErrorType(errMsg), 'Should retry: ' + errMsg);
            System.Assert.isTrue(
                ErrorTypeEvaluator.evaluateErrorType(errMsg.toUpperCase()),
                'Should retry (uppercase): ' + errMsg
            );
        }
    }

    @IsTest
    static void testEvaluateErrorType_DeadlockSpecialCase() {
        // Assert deadlock conditions handle the logical AND execution correctly
        String validDeadlock = 'UNHANDLED_TRIGGER_EXCEPTION: record unavailable due to lock deadlocks';
        String incompleteDeadlock1 = 'UNHANDLED_TRIGGER_EXCEPTION: generic execution problem';
        String incompleteDeadlock2 = 'Standard application exception mentioning lock deadlocks';

        // Valid deadlock matches step 2 explicitly
        System.Assert.isTrue(
            ErrorTypeEvaluator.evaluateErrorType(validDeadlock),
            'Should retry matching both deadlock criteria'
        );

        // Incomplete matches should miss step 2 and fall through to step 4 (default fallback strategy)
        System.Assert.isTrue(
            ErrorTypeEvaluator.evaluateErrorType(incompleteDeadlock1),
            'Should fall through to default true strategy'
        );
        System.Assert.isTrue(
            ErrorTypeEvaluator.evaluateErrorType(incompleteDeadlock2),
            'Should fall through to default true strategy'
        );
    }

    @IsTest
    static void testEvaluateErrorType_PrecedenceNonRetryableWins() {
        // Assert priority order when an error log contains elements from multiple sections
        // Even if 'read timed out' is a retryable pattern, 'nullpointerexception' evaluates first
        String conflictingError = 'Error log containing read timed out along with a nullpointerexception message';

        System.Assert.isFalse(
            ErrorTypeEvaluator.evaluateErrorType(conflictingError),
            'Non-retryable regex evaluation must take precedence'
        );
    }

    @IsTest
    static void testEvaluateErrorType_DefaultStrategyFallback() {
        // Assert unrecognized strings always drop down to true
        String unknownVendorError = 'Unexpected custom code 909 from external fulfillment system';

        System.Assert.isTrue(
            ErrorTypeEvaluator.evaluateErrorType(unknownVendorError),
            'Unmapped errors must default to true'
        );
    }
}
