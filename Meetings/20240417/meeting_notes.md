# Event Working Group Meeting Notes

### Date: 20240417

### Attendees:
- Austin Fatheree
- Ilia Agafonov
- Ethan Celletti
- Matt
- Lachlan Witham
- Zhenya Usenko

### Agenda and Discussion Points:

1. **Token Vote:**
   - The group agreed to ratify the first token mint based on the discussion in [GitHub Issue #12](https://github.com/icdevs/ICEventsWG/issues/12).

2. **Formalize WG Member List and Role Assignment:**
   - **Decision:** Formal WG member list will be used. Members can join by asking, and roles will be assigned liberally unless there is a consensus to limit a role.
   - **Specific Roles Discussed:**
     - **Austin Fatheree:** Thought Leader, Voting Member
       - **Assignment:** Create weekly meeting agenda.
     - **Roles Defined:**
       - **Thought Leader:** Review issues, provide proactive responses, and insight.
       - **Voting Member:** Vote on "Vote Required" GitHub issues.
       - **Secretary:** Responsible for recording meetings, producing notes, and providing attendance.
   - Austin will brainstorm a more formal list of roles.

3. **Issue Review:**
   - **Issue #2 - Two Types of Subscriber Approach:**
     - General consensus reached; raised by Ilia. Discussion focused on systems requiring trusted responses, especially in smaller systems or those dealing only with trusted canisters.
     - Austin asked about the type of response, leading to a decision on using open metadata so systems can implement ICRC16/Value, ensuring that the response from trusted endpoints should only include metadata, not rich stateful data.
    
     - We have general consensus.
```
  icrcx_event_listener : (event: Event) -> async (); //untrusted
  icrcx_event_listener_trusted : (event: Event) -> async (opt Value);  //#Map for maps, #Nat for ID.
```
Presupposition: The trusted return type should only include response metadata and typically not have rich, stateful data.(emit your own event if you want to talk back to a publisher).

4. **Issue #3 - Message Identifier Discussion:**
     - Raised by Austin, discussion on whether to use variants for message identifiers and the necessity of size checking if using a 'nat'.
     - Consensus on broadcaster needing to validate message size.
     - Group ready to vote on at least using nats for message identifiers, and Previous Message optional.
     - Notification ID will be moved to a different Issue
5. **Ilia’s Pull Request:**
     - Update on the name in the draft related to event identifiers. (Make sure it has Events in it ... see Pull Request 1).

### Action Items:
- **Austin Fatheree:** Create Votes for Issue 2 and 3
- **Austin Fatheree:** Create Role list
- **Group:** Continue to create new issues
