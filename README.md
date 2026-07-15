# apex-async-retryable-tasks

> _A robust and resilient integration experiment for async Callouts._

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

You can follow the documentation under the following links:

- ## [Integration Topics Considerations](./docs/integration_topics_considerations.md)

- ## [Solution Proposal](./docs/solution_proposal.md)

<p>&nbsp;</p>
