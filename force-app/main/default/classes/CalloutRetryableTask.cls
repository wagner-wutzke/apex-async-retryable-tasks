public class CalloutRetryableTask extends AbstractRetryableTask {
    //

    public override void process(QueueableContext context) {
        Integer random = Integer.valueOf(Math.random() * 100);

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');

        String calloutUrl = parameters.get('callout_url').toString();

        try {
            request.setEndpoint(calloutUrl);
            HttpResponse response = http.send(request);
            finalizeTask(AbstractRetryableTask.STATUS_FINISHED_SUCCESS);
        } catch (Exception ex) {
            throw new RetryableTaskException(ex.getMessage());
        }
    }

    public override String getIdempotencyKey() {
        return this.parameters.get('idempotency_key').toString();
    }
}
