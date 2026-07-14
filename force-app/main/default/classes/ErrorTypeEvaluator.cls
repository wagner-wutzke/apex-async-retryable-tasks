public class ErrorTypeEvaluator {
    //

    // Pre-compiled patterns optimize performance by avoiding runtime compilation

    private static final Pattern NON_RETRYABLE_PATTERN = Pattern.compile(
        '(required_field_missing|field_custom_validation_exception|string_too_long|' +
        'bad request|unauthorized|forbidden|nullpointerexception|invalid_field)'
    );

    private static final Pattern RETRYABLE_PATTERN = Pattern.compile(
        '(read timed out|connection timed out|callout loop|too many requests|' +
        'internal server error|service unavailable|gateway timeout)'
    );

    public static Boolean evaluateErrorType(String errorMessage) {
        if (String.isBlank(errorMessage)) {
            return false;
        }

        String lowerMessage = errorMessage.toLowerCase();

        // 1. Check Non-Retryable
        if (NON_RETRYABLE_PATTERN.matcher(lowerMessage).find()) {
            return false;
        }

        // 2. Special Case (Deadlock)
        if (lowerMessage.contains('unhandled_trigger_exception') && lowerMessage.contains('lock deadlocks')) {
            return true;
        }

        // 3. Check Retryable
        if (RETRYABLE_PATTERN.matcher(lowerMessage).find()) {
            return true;
        }

        // Default strategy: If it's an unrecognized error, default to true to give it the benefit of the doubt
        return true;
    }
}
