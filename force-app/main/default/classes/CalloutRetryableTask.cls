@isTest
public class CalloutRetryableTask extends AbstractRetryableTask {
    //

    public override void process(QueueableContext context) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        try {
            String credentialName = parameters.get('named_credential').toString();
            ConnectApi.NamedCredential namedCredential = ConnectApi.NamedCredentials.getNamedCredential(credentialName);
            request.setEndpoint('callout:' + namedCredential.developerName);
            HttpResponse response = http.send(request);
            if (response.getStatusCode() != 200) {
                throw new RetryableTaskException(response.getStatus());
            }
        } catch (Exception ex) {
            throw new RetryableTaskException(ex.getMessage());
        }
    }

    public override String getIdempotencyKey() {
        return this.parameters.get('idempotency_key').toString();
    }
}
