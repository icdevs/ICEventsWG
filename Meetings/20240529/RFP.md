# RFP: ICRC-16 Compatible Rust Cargo Component for the Internet Computer

## Overview

- **Status**: Open

- **Project Type**: Cooperative - Multiple workers can submit work, and the bounty is shared.

- **Time Commitment**: Estimated <1 week

- **Experience Level**: Beginner to Intermediate

- **Size**: Possible < USD 5,000 via Grant, 60,000 Event Utility Working Group Tokens/hr.

- **Proposing Group**: The Events Utility Working Group

## Description

In the rapidly emerging sector of decentralized applications, standardization of data exchange formats is crucial for interoperability and efficient communication between canisters on the DFINITY Internet Computer. The ICRC-16 EnhancedValue standard proposes a Candid-Compatible interface for a flexible, standardized exchange of unstructured data.

Our goal is to create a Rust cargo component that fully implements the ICRC-16 EnhancedValue standard, ensuring compatibility and functionality in a Rust project environment. This component should provide developers with the necessary tools to seamlessly integrate and manipulate ICRC-16 data types.

## Project Deliverables

This Rust cargo component should provide:

1. **Data Types**:

- Define all necessary Rust data types corresponding to the ICRC-16 EnhancedValue Candid variants.

2. **Conversion Functions**:

- Implement helper functions that facilitate the conversion between ICRC-16 variants and native Rust types.

3. **Interface Methods**:

- Provide implementation for the interaction of these data types with the Internet Computer, including serialization and deserialization to/from Candid.

4. **Size Calculation**:

- Provide implementation for the estimation of the size of an object in bytes.

## Acceptance Criteria

The deliverable must:

- Fully support all variants outlined in the ICRC-16 standard’s Candid definition.

- Include comprehensive documentation detailing usage and integration processes.

- Provide a robust suite of unit tests demonstrating the correctness of the implementations and conversion functions.

- Be published on a public repository under an open-source license (preferably MIT or similar).

- Offer examples demonstrating practical implementations of the component in sample Rust projects.

## How to Apply

Interested developers should submit an application via the Public Developer Grants process as outlined here: https://forum.dfinity.org/t/introducing-public-developer-grants/28863 and should attend the [Event Utility working group](https://forum.dfinity.org/t/technical-working-group-inter-canister-event-utility-working-group/29048) to share their proposal.

## References

- [ICRC-16 Standard Overview](https://github.com/dfinity/ICRC/issues/16)

- [Candid Specifications](https://github.com/dfinity/candid/blob/master/spec/Candid.md)

- [Motoko Implementation - CandyShared](https://github.com/icdevsorg/candy_library)

For any queries or clarifications, reach out on the discussion thread or comment on the issue at https://github.com/icdevs/ICEventsWG/issues/32.

## Conclusion

The creation of this Rust cargo component is a step towards enhancing the ecosystem's capability to manage and utilize unstructured data effectively, following the ICRC-16 standard. We invite capable Rust developers to contribute to this effort, paving the way for more standardized and cohesive data handling within the Internet Computer’s diverse and expanding application landscape. This component will be a key input into the rust client for ICRC-72 and a such the Event Utility WG is offering 60,000 tokens / hour spent on the item given an agreed upon estimate. We would recommend this project be granted a DFINITY public grant as well, although it my not be a full $5,000 grant.