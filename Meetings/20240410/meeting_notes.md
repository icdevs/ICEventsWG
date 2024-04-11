# Event Working Group Meeting Notes

### Date: April 10, 2024

### Attendees:
- Ilia Agafonov
- Austin Fatheree
- Ethan Celletti
- Byron Becker
- Lachlan Witham (Icarus)
- Jorge Costa
- Gilles Pirio
- Sam DRISSI

### Introductions:
- **Ethan Celletti:** Working on an RSS pubsub, C# agent, Motoko, and a game on the IC (DAOBall).
- **Lachlan Witham (Icarus):** From Melbourne, AU. Gen2 Node Provider. Part of the decentralized AI Working Group, interested in infrastructure and keen to listen in.
- **Jorge Costa:** Has been developing for two months, observing. Software developer for 6 years, with experience in AI, contracts for EVM.
- **Gilles Pirio:** Based in San Francisco. Former DFINITY employee, here to learn.

### Discussion Points:
- **Naming Conventions:**
  - Ilia highlighted the importance of including “event” in the standard for clarity.

- **Identifying Producers and Consumers:**
  - Byron Becker discussed the potential need for two identifiers to distinguish between producers and consumers. He suggested using Nats as ULIDs for this purpose.

- **ID Systems:**
  - Gilles Pirio recommended looking into RabbitMQ for a good ID system, emphasizing its effectiveness.

- **Publication Modes:**
  - Byron raised a question about publication modes, differentiating between wanting the latest data versus wanting the entire history.
  - Gilles questioned the necessity of data history.

- **History and Pub/Sub Separation:**
  - Austin suggested possibly splitting history and pubsub into two parts: a basic ICRC-72 and an extension ICRC.

- **Data Encoding:**
  - Icarus brought up CBOR, noting its expressiveness and efficiency, and mentioned creating a GitHub issue regarding it. However, Austin noted the difficulty of working with CBOR in Motoko.

- **Error Handling and Resending:**
  - Gilles inquired about error handling and the possibility of resending data similar to RabbitMQ, indicating different application modes.

- **Standard Flexibility:**
  - Austin emphasized that the standard should support a wide range of operations and applications, from simple single canister pub/sub models to massive IC-wide tools, with the publish method remaining consistent across various expectations and system specifics.

### Action Items:
- **Austin Fatheree:**
  - To create an open chat room.
  - To collect open chat and principals, and create a GitHub issue accordingly.
- **Working Group:**
  - To address GitHub issues asynchronously.
  - To set the notification bell on the Working Group GitHub.

### Next Meeting:
- Scheduled for next week.

---

### Additional Notes:
- The meeting focused on addressing technical aspects of event publishing and subscription on the IC, including naming conventions, identifying producers and consumers, and discussion on publication modes.
- Participants brought a diverse set of experiences and backgrounds, enriching the discussion with different perspectives on how to improve the event working group's standards and practices.
- The action items set a clear path forward for the group, emphasizing collaboration and the efficient use of GitHub for asynchronous work.
