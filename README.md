# apex-async-retryable-tasks
A robust framework for retryable asynchronous tasks.

## Robust and resilient integration with async Callouts
When build building complex integrations unsing async Callouts, how you think about failure, about resilience, about the big picture, system architecture.
So, what do you say? Yeah, this question, it's a classic for a reason. It's not really about the code itself.
It's about proving you can build systems that don't just, you know, fall over at the first sign of trouble.

Why isn't a simple basic approach good enough? Let's take a look at what happens when things break. Caouse let's be real, the network always fails eventually.
See, a simple call out is just well, it's fragile. It's basically living on a prayer inside a single try catch block, hoping the network is perfect. But it is not.
A robust strategy though, it's the complete opposite. It expects failure. It plans for it from the very beginning, running things in the background to protect the user
experience, own resources and making smart decisions about when and how to try again.

### Part 1
All right. Now, for the main event, **you've got to know when to even bother retrying**. Seriously, you don't want your system just spinning its
wheels, wasting time and resources trying to fix something that is permanently broken. And this table here just lays it all out perfectly.

<p align="center">
<img width="600" height="300" alt="Screenshot from 2026-07-11 11-55-20" src="https://github.com/user-attachments/assets/a8d4cdec-3040-4905-88be-8f35f819d0f7" />
</p>

Look, we only want to retry transient issues. You know, temporary glitches, network hiccups, a 503 service unavailable. That's a perfect example.
The servers just saying, "Hey, I'm swamped right now. Come back in a bit." So, yeah, trying again makes total sense. But on the flip side, we have
permanent errors. Things like a 400 bad request. That means we sent something wrong. Retrying that over and over, it's just going to fail every single time. 

### Part 2
Part two is about **going asynchronous**. This is all about protecting two things. The user experience and your own systems resources.
By shifting all this retry logic into a background job like with Queueable Apex, the user is completely unaware. They're not stuck watching a loading spinner.
And here's the best part, the big bonus. We get access to way higher governor limits, which gives our process so much more breathing room to actually get the job done right. 

### Part 3
Part three is all about **timing**.
It's not enough to just retry. You have to retry smart. Instead of just, hammering the external system over and over the second it fails, which can actually make things worse, we need to be a little more 'polite'. And that's where something called exponential backoff comes in. Fancy term for a simple idea. After the first attempt fails, we wait, let's say, 5 seconds. 
If it fails again, we wait longer, maybe 15 seconds, then 30. We're giving the other system progressively more and more time to recover.
It's a really respectful and super effective way to deal with things like rate limiting or temporary server overloads.

### Part 4
This one is simple, but absolutely vital. **You have to limit your retries**. 
Just pick a reasonable number, like 3 to 5 attempts, and that's it. This is your safety valve. 
It's what stops you from getting stuck in an infinite loop that consumes all your resources trying to hit a service that might be down for hours.

### Part 5
You need a **state management** approach. You got to keep track of the original data and how many times you've tried.

### Part 6
Additionally, keeping track of tasks **idempotency** is crucial. You don't want to fire the same order request twice and have duplicate orders at the end.

### Part 7
Then **logging and monitoring**. I mean, log everything, every attempt, every success, every failure. This will save you when it's time to debug.

### Part 8
And finally, have a **plan for total failure**. What happens when the maximum retries count have been reached and it still doesn't work?\
Do you email an admin, update a record? You absolutely have to have a plan for this final failure scenario.


So, that's the theory. 
This framework tries to implement each of the mentioned points in a flexible, configurable and extensible fashion, so that it can easily be used in real world solutions. 



## What happens when using the framework
<p align="center">
  <img width="900" height="500" alt="image" src="https://github.com/user-attachments/assets/523794d8-ce8e-4ac9-986e-89c8b930571e" />
</p>
