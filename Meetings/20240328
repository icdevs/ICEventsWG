Meeting notes 20240328 - Events working group

Points of Discussion:

Generic Event vs Preformatted Event.


Generic Events:

Pros:

- You don't have to know the structure before hand.
- Better for Interoperability

Cons:

- How do you trust the event came from where it says it comes from?
- Do you trust your subscriber.
	- Broadcast a one shot to subscriber - stops subscription and waits
	- Confirm reciept (awaited) - They should trust the utility. - Send cycles to pay for the notification(or maybe 2x). Restarts your subscription(sends the next in the queue if available)


- Replayability
- Stream Storage

- How do I know I missed a message
  - what kind of IDs do we use? Can we use these to detect that we missed a message?




Publisher

`icrcX_register_publisher(...) : ...`
`icrcX_register_event(...) : ....`


Relayer

`icrcX_confirm_event(....) : ...` //optional
`icrcX_publish(...) : ....`

Subscriber

`icrcX_register_subscriber(...) : ....`
`icrcX_subscribe(...) : ....`
`icrcX_event_listener(....) : ...`

Types:

- Value - ICRC Spec
- ICRC16 - Superset of Value

or

- hard coded
  - From_candid / to_candid

Decision Points

- Public WG?
- Weekly or bi weekly
