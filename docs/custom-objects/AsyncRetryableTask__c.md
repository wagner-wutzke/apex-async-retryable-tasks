# Async Retryable Task

## API Name
`AsyncRetryableTask__c`

## Fields
### Apex Job Id

The async queueable job Id

**API Name**

`ApexJobId__c`

**Type**

*Text*

---
### Attempts
**Required**

**API Name**

`Attempts__c`

**Type**

*Number*

---
### Execution End Datetime

When this task has ended its executed (after all retries)

**API Name**

`ExecutionEndDatetime__c`

**Type**

*DateTime*

---
### Execution Start Datetime

When this task started its execution

**API Name**

`ExecutionStartDatetime__c`

**Type**

*DateTime*

---
### Idempotency Key
**Required**

The idempotency key for checking if the task is already in execution

**API Name**

`IdempotencyKey__c`

**Type**

*Text*

---
### Max Retries
**Required**

The maximum number of retries for this task

**API Name**

`MaxRetries__c`

**Type**

*Number*

---
### Serialized Parameters

Task parameters serialized as JSON object

**API Name**

`SerializedParameters__c`

**Type**

*LongTextArea*

---
### Status
**Required**

The task status used to check how to proceed

**API Name**

`Status__c`

**Type**

*Picklist*

#### Possible values are
* Created
* Executing
* Finished with Fail
* Finished with Success
* Error

---
### Task Class Name
**Required**

The concrete class implementing this task

**API Name**

`TaskClassName__c`

**Type**

*Text*

---
### Task Config Developer Name
**Required**

The Configuration CMDT Developer Name

**API Name**

`TaskConfigDeveloperName__c`

**Type**

*Text*

---
### Task Duration (sec)

**API Name**

`TaskDuration__c`

**Type**

*Number*