# apex-async-retryable-tasks
>_A robust and resilient integration experiment for async Callouts._
<p>&nbsp;</p>

When build building complex integrations unsing async Callouts, how you think about failure, about resilience, about the big picture, system architecture.
Resilient describes something or someone that can easily recover, bounce back, or adjust to misfortune, change, or damage.
So, what do you say? Yeah, this question, it's a classic for a reason. It's not really about the code itself.
It's about building systems that don't just, you know, fall over at the first sign of trouble.

Why isn't a simple basic approach good enough? Let's take a look at what happens when things break. Cause let's be real, the network always fails eventually.
See, a simple call out is just well, it's fragile. It's basically living on a prayer inside a single try catch block, hoping the network is perfect. But it is not.
A robust strategy though, it's the complete opposite. It expects failure. It plans for it from the very beginning, running things in the background to protect the user
experience, own resources and making smart decisions about when and how to try again.

## So what are we doing here?
So in this article, we are going to mention 8 key strategies that, in my opinion, must be at least considered when building reliable asynchronous integrations.
At first, It doesn’t really matter which platform or language it is being used, but only the concepts.

After those considerations, I am going to present a first technical solution **experiment** for the Salesforce platform. It is an experiment, so feel free to make your comments.\
At the end we all can learn something.

## Integration topics considerations
### 1. Is a retry really helpful?
All right. Now, for the main event, **you've got to know when to even bother retrying**. Seriously, you don't want your system just spinning its
wheels, wasting time and resources trying to fix something that is permanently broken. And this table here just lays it all out perfectly.

<p align="center">
<img width="600" height="300" alt="Screenshot from 2026-07-11 11-55-20" src="https://github.com/user-attachments/assets/a8d4cdec-3040-4905-88be-8f35f819d0f7" />
</p>

Look, we only want to retry transient issues. You know, temporary glitches, network hiccups, a 503 service unavailable. That's a perfect example.
The servers just saying, "Hey, I'm swamped right now. Come back in a bit." So, yeah, trying again makes total sense. But on the flip side, we have
permanent errors. Things like a 400 bad request. That means we sent something wrong. Retrying that over and over, it's just going to fail every single time. 

### 2. Going asynchronous
This is all about protecting two things. The user experience and your own systems resources.
By shifting all this retry logic into a background job like with Queueable Apex, the user is completely unaware. They're not stuck watching a loading spinner.
And here's the best part, the big bonus. We get access to way higher governor limits, which gives our process so much more breathing room to actually get the job done right. 

### 3. Timing
It's not enough to just retry. You have to retry smart. Instead of just, hammering the external system over and over the second it fails, which can actually make things worse, we need to be a little more 'polite'. And that's where something called exponential backoff comes in. Fancy term for a simple idea. After the first attempt fails, we wait, let's say, 5 seconds. 
If it fails again, we wait longer, maybe 15 seconds, then 30. We're giving the other system progressively more and more time to recover.
It's a really respectful and super effective way to deal with things like rate limiting or temporary server overloads.

### 4. Limit your retries
This one is simple, but absolutely vital.
Just pick a reasonable number, like 3 to 5 attempts, and that's it. This is your safety valve. 
It's what stops you from getting stuck in an infinite loop that consumes all your resources trying to hit a service that might be down for hours.

### 5. State management
You got to keep track of the original data and how many times you've tried.\
If everything goes down, it is important to have the last state persisted somewhere, in order to recover properly.

### 6. Tasks idempotency
Additionally, keeping track of tasks **idempotency** is crucial.\
You don't want to fire the same order request twice and have duplicate orders at the end.

### 7. Logging and monitoring
I mean, log everything, every attempt, every success, every failure.\
This will help you when it's time to debug.\
It also serves traceability, reporting, analyitics and failure alerting for misbehaving integrations.

### 8. Plan for total failure
What happens when the maximum retries count have been reached and the operation behind the task still didn't work?\
Do you email an admin, update a record? You absolutely have to have a plan for this final failure scenario.

## Good for now
So, that's to the ideas.\
Now that we have some key aspects for consideration when build our framework, let's try to implement them in a flexible, configurable and extensible fashion, so that it can easily be applied in real world scenarios. 
<p>&nbsp;</p>

## Solution Proposal

When thinking of a framework for handling async retriable integration tasks, I imagine having some software components I can reuse for doing the same thing over and over again, but for different and specific use cases.\
Here are some use cases I can think of now:
- Sending a flight booking batch update request to an external system.
- Sending a quotation request to an external system with some product and customer data.
- Sending a batch product reservation request to an external warehouse system and saving the confirmation response locally.

Generally speaking it would look like this:
<p align="center">
  <img width="700" height="300" alt="image" src="https://github.com/user-attachments/assets/5e28c4ce-0b38-4f8b-be5a-34dfe603e8e0" />
</p>

- **Integration Application**: Is the application where we are creating and firing the integrations tasks.
- **Concrete Task**:
  - Is the Apex class instance implementing the real integration task execution.
  - It contains an instance of the Task Configuration.
  - It extends some basic functionallity defined in the Abstract Task class.
- **Task Configuration**: it defines some configurations for the the task, like:
  - class name to be instentiated when creating a new concrete task.
  - retry max amount
  - configuration name to be referenced in the integration application.
- **Task Manager**: Is a class responsible for:
  - creating new concrete task instances by their configuration name.
  - enqueuing the tasks to be executed.
  - handling retry on task execution errors. 

In order to simplify, here is what I am expecting from the framework:
- I define a concrete class implementation to be instantiated by the framework when I call create (e.g. `QuoteRequestRetryableTask`).
- I define a Custom Metadata Type record with the configurations for my concrete tasks (`AsyncRetryableTaskConfiguration__mdt` with `DeveloperName` = 'QuoteRequestRetryableTask').
- By calling `createTask` on the Task Manager, I give the defined `DeveloperName` as parameter. The Task Manager creates dinamically a concrete task instance of `QuoteRequestRetryableTask` with the provided configuration in the CMDT and returns it.
- After I have that concrete instance of the `QuoteRequestRetryableTask`, I call 'enqueueTask' on the Task Manager.
- The task gets enqueued and executed. If it fails, the Task Manager takes care of rescheduling it for execution, or finishes it, according to the type of ocurred error or retries exhaustion.

<p>&nbsp;</p>

## What happens when using the framework
<p align="center">
  <img width="900" height="500" alt="image" src="https://github.com/user-attachments/assets/523794d8-ce8e-4ac9-986e-89c8b930571e" />
</p>
