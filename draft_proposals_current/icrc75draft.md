
Here is the ICRC-75 Standard:

|ICRC|Title|Author|Discussions|Status|Type|Category|Created|
|:----:|:----:|:----:|:----:|:----:|:----:|:----:|:----:|
|75|Minimal Membership Standard|Austin Fatheree (@skilesare), @ava-vs, Matt Harrmon, Lachlan, Byron Becker, Ethan|https://github.com/dfinity/ICRC/issues/72|Draft|Standards Track||2024-05-08|

# ICRC-75: Minimal Membership Standard

## Data Representations

This section defines the core data types and structures used within ICRC-75 for representing identities, lists, and permissions associated with the management of composable identity lists on the Internet Computer.

### Identity

An identity in ICRC-75 is associated with an individual or entity capable of interacting within the ecosystem. The primary representation of an identity is a `Principal`, which is a unique identifier assigned to users and canisters on the Internet Computer.

```candid
type Identity = Principal;
```

The `Principal` is a type intrinsic to the Internet Computer, providing a secure and verifiable way to represent identities. The identities are text encoded and include a checksum for integrity verification.

### Account

An account in ICRC-75 is similar to an ICRC-1 Account type.

```candid
type Account = {
  owner: Principal;
  subaccount: Blob
};
```

### DataItem

A data item in ICRC-75 represents an unstructured ICRC-16 data item that can be a part of a list. This enables the ICRC-75 system to be used for data structures outside of the set of Identities, Accounts, and Lists.

```candid
type DataItem = ICRC16;
```

### List

A list in ICRC-75 represents a collection of identities and potentially other nested lists, enabling the composition of complex group structures. Each list is uniquely identified by a textual name within a namespace, facilitating organized management and referencing.

```candid
type List = Text;
```

Lists can include members that are direct identities or other lists, enabling hierarchical groupings. This composability supports the creation of extensive and flexible group structures, such as combining multiple subgroups into a larger collective group.



Lists can include members that are direct identities or other lists, enabling hierarchical groupings. This composability supports the creation of extensive and flexible group structures, such as combining multiple subgroups into a larger collective group.

### Permissions

Permissions in ICRC-75 define the actions that identities or lists can perform on other lists. The permissions are categorized into various types, each representing a specific capability:

```candid
type Permission = Variant {
    Admin;        // Full administrative rights, including managing permissions and sublists.
    Read;         // Permission to view the list and its members.
    Write;        // Ability to modify the list, add or remove members.
    Permissions;  // Rights to modify the permissions of other identities in the list.
};
```

- **Admin**: Carries the rights to perform any administrative tasks on the list such as renaming, deleting, or configuring permissions.
- **Read**: Allows the viewing of the list's contents, enabling identities with this permission to see which other identities or lists are members.
- **Write**: Grants the ability to add or remove identities and nested lists, as well as to modify members within the list.
- **Permissions**: Entrusted with managing who can modify the read/write permissions associated with the list, adding an additional layer of administrative control.  Ading and removing admins is SHOULD be restricted to the Admin role

Through these permissions, ICRC-75 can effectively manage access and actions that can be performed by various identities across different lists within the ecosystem.

This section defines the necessary data types and structures used within ICRC-75 for managing composable identity lists.

### Types for managing lists

The types defined to manage the lists inside the ICRC-75 standard are critical for understanding how identities and lists are structured, how they interact, and how permissions are managed. Below is an explanation of each type:

1. **`ListItem`**:
   - A `variant` that can hold either an `Identity` or a `List` or an `Account` or a `DataItem`. This structure allows each list item to be either a direct reference to an identity (a principal on the Internet Computer) or another list (effectively creating nested or hierarchical lists).

2. **`AuthorizedRequestItem`**:
   - A `record` combining an `ListItem` and a double vector of `Lists`. Represents a request to check if specific identities are authorized in the context of specified lists. This aids efficient batch processing of access checks.

3. **`AuthorizedResponse`**:
   - A vector of type `Bool`. It returns a series of Boolean values that correspond to the authorization check result of each item in the `AuthorizedRequestItem`. True means authorized; false means not authorized.

4. **`IdentitiesResponse`** and **`ListsResponse`**:
   - Both are simple vectors containing either `Identity` or `List` items, respectively. Used to return results in queries for members of a list (`IdentitiesResponse`) or sublists (`ListsResponse`).

5. **`ManageListPropertyRequestAction`**:
   - A comprehensive `variant` for various list-management actions such as renaming a list (`Rename`), deleting a list (`Delete`), or changing permissions (`ChangePermissions`). The `ChangePermissions` variant is particularly detailed, allowing addition or removal of permissions for reading, writing, administrating, or managing permissions of the list for specific `ListItem`s.

6. **`ManageListMembershipResult` and `ManageListPropertyResult`**:
   - Both types encapsulate a common pattern where an operation can result in success or failure:
     - `Ok`: Indicates success and holds a `TransactionID` which can be used for auditing or tracking.
     - `Err`: Represents an error and holds an error struct that can explain what went wrong.

#### Nested Permission Details:

The `ChangePermissions` in `ManageListPropertyRequestAction` offers granular controls divided among various scopes like `read`, `write`, `admin`, and `permissions`. Each scope permits adding or removing permissions via adding or removing `ListItem`s (either identities or sublists) that can perform associated actions.

- `add` and `remove`: Allow the modification of lists or identities that have specific permissions for detailed access control. 
- adding the anon principal to read will give universal access to read. The anon principal is not allowed for any other permission.

### Usage Context

These types are used across the API of the canister to perform tasks like:
- Querying membership and sublist structures.
- Authorizing transactions or operations based on identity and list membership.
- Modifying properties or memberships of lists, thus allowing dynamic control over complex organizational structures represented in lists.

```candid

type ListItem = variant {
    Identity: Identity;
    List: List;
    Account: Account
    DataItem: DataItem
};

type AuthorizedRequestItem = record { ListItem; [[List]] };

type AuthorizedResponse = vec Bool;

type IdentitiesResponse = vec Identity;
type ListsResponse = vec List;

type ManageListPropertyRequestAction = variant {
  Create = record {
    admin = ?ListItem;
    metadata = Map;
    members = [ListItem]
  };
  Rename = Text; 
  Delete;
  Metadata: {
    key = text;
    value = opt Value
  }; 
  ChangePermissions = variant {
    read = variant{
      all;
      add = ListItem;
      remove = ListItem;
    };
    write = variant{
      add = ListItem;
      remove = ListItem;
    };
    admin = variant{
      add = ListItem;
      remove = ListItem;
    };
    permissions = variant{
      add = ListItem;
      remove = ListItem;
    };
  } 
};

type ManageListMembershipResult = ?(variant {
  Ok: TransactionID
  Err: Error;
});

type ManageListPropertyResult = ?(variant {
  Ok: TransactionID
  Err: Error;
});
```

### Canister Management

```candid
type ManageRequestItem = variant { 
  UpdateDefaultTake = nat;
  UpdateMaxTake = nat;
  UpdatePermittedDrift = nat;
  UpdateTxWindow = nat;
  UpdateOwner = principal;
};

type ManageResult = ?(variant {
  Ok: TransactionID
  Err: Error;
});

```


### Data Structure for Identity Tokens

Identity tokens within the ICRC-75 standard play a crucial role as cryptographic proofs of membership for entities and data items listed within any given list. These tokens enable identities to establish their association rights with respect to various resources or services managed on the Internet Computer.

#### Definition

```candid
type IdentityToken = record {
    authority: Principal;      // Principal of the canister issuing the token.
    namespace: Text;      // The list namespace to which the token pertains.
    issued: Nat;          // Timestamp of when the token was issued.
    expires: Nat;         // Timestamp of when the token expires.
    member: ListItem;         // Principal of the user to whom the token is issued.
    nonce: Nat;           // A unique nonce to ensure the freshness of the token.
};

type IdentityCertificate = record {
    token: IdentityToken;      
    witness: Witness;      
    certificate: Blob;      
};

  /// The type of witnesses. This correponds to the `HashTree` in the Interface
  /// Specification of the Internet Computer
  type Witness = variant {
    #empty;
    #pruned : Blob;
    #fork : (Witness, Witness);
    #labeled : (Blob, Witness);
    #leaf : Blob;
  };
```


#### Description

- **authority**: This field holds the principal identifier of the canister that issues the identity token. It acts as the trusted authority that validates the identity's membership within the specified list.

- **namespace**: A textual identifier representing the specific list or domain within the standard for which the token is applicable. This allows for distinguishing different groups or access levels under the same authority.

- **issued and expires**: These fields mark the validity timeframe of the token, detailing precisely when the token becomes active and when it ceases to be valid. It is crucial for temporal verification, ensuring tokens are used within their designated periods.

- **member**: Contains the ListItem identifier of the entity that possesses the token. This field is essential for linking the token to a specific member within the list, enabling their identification, authentication, or membership.

- **nonce**: A unique numerical value used once to guard against replay attacks. This ensures that each token is uniquely tailored for a single use and cannot be maliciously reused.

### Usage

Identity tokens are used to provide a verifiable mechanism for identities to prove their membership within specific lists when interacting with other canisters or services. When an identity needs to interact or access a resource, it presents its token; the resource can then validate this token by checking its integrity and authenticity against the issuing authority’s public records. This system enables decentralized and secure verification of memberships without constant online checks with the authority canister, thereby reducing overhead and enhancing performance across the network.

### Security and Verification

To ensure the security of identity tokens, the issuing canister hashes the token records to a Merkle tree and the subnet signs the root. During verification:

1. **Record Submission**: The service demanding proof of membership requires the submission of the token record.
2. **Witness Provision**: Accompanying the record, a witness (part of the Merkle tree) is also provided, confirming the particular entry’s validity lined to the signed root.
3. **Certificate Checking**: Lastly, a certificate signed by the subnet and produced by the canister, which includes the Merkle root, is verified to ensure that the witness and the record correspond to the signed state of the issuing canister.

By using cryptographic proofs and decentralized verification methods, ICRC-75 ensures that identity tokens are both secure and efficient in managing identity verifications across the Internet Computer ecosystem.

### Generally-Applicable Specification

We next outline general aspects of the specification and behavior of query and update calls defined in this standard. Those general aspects are not repeated with the specification of every method, but specified once for all query and update calls in this section.

#### Batch Update Methods

Please reference [ICRC-7](https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md#batch-update-methods) for information about the approach to Batch update Methods.

#### Batch Query Methods

Please reference [ICRC-7](https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md#batch-query-methods) for information about the approach to Batch update Methods.

#### Error Handling

Please reference [ICRC-7](https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md#error-handling) for information about the approach to Batch update Methods.

#### Other Aspects

Please reference [ICRC-7](https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md#other-aspects) for information about the approach to Batch update Methods.

## Function Definitions

### ICRC-75 Standard Function Categories

Functions within the ICRC-75 standard are categorized into specific groups based on their operational functionalities. This categorization helps in organizing the methods according to their purposes such as list management, identity verification, membership querying, etc. Here’s the detailed segregation:

#### Manage List Update Functions

These functions enable the dynamic management and update of lists according to specified criteria by authorized users. They facilitate the central administration tasks involved in the identity list structure.

##### icrc_75_manage

This function provides a generalized interface for managing various properties and behaviors within lists. Administrators can invoke this function to submit batches of management requests, which could range from adding new identities to adjusting configuration settings for the list.

```candid
// Add or remove identities and sublists in a list
icrc_75_manage: (vec ManageRequest) -> async vec ManageResult;
```

##### icrc_75_manage_list_membership

Specific to managing the membership of lists, this function allows the addition or removal of identities or sub-lists. It is essential for maintaining the composition of lists, ensuring that only authorized entities are part of a list, and managing nested list structures effectively.

```candid
// Add or remove identities and sublists in a list
icrc_75_manage_list_membership: (vec record {
  list: List;
  memo: opt blob;
  created_at_time: opt nat;
  action: variant { 
    Add: ListItem; 
    Remove: ListItem }
  }) -> async vec opt ManageListMembershipResult;
```

##### icrc_75_manage_list_properties

Focused on manipulating the direct properties of a list, such as renaming or deleting it, this function serves administrative purposes. It can be used to enforce changes in the list’s metadata or structure, adhering to governance rules or updates in organizational structure.

```candid
// Manage list itself (rename, delete)
icrc_75_manage_list_properties: (vec { record { 
  list: List;
  memo: blob;
  from_subaccount: ?blob; // in case the item requires some kind of payment
  created_at_time: nat;
  action: ManageListPropertyRequestAction ;
}}) -> async vec ManageListPropertyResult;
```

#### List Management Query Functions

These functions facilitate the retrieval of information about lists and their administrative settings without modifying any existing data. This function category is crucial for transparency, audit, and reporting purposes.

##### icrc_75_get_lists

Allows retrieval of lists in a pageable fashion, making it scalable for environments with large numbers of lists. It can be used to browse through lists based on pagination settings.

If the filter is provided then only items that start with the provided text should be retrieved.

```candid
type ListRecord = {
  namespace: Text;
  metadata: ?Map;
}
// Retrieve lists, pageable
icrc_75_get_lists: (filter: optText; bMetadata: Bool, prev: opt List, take: opt nat) -> query async vec ListRecord;
```

##### icrc_75_get_list_members_admin

Retrieve administrative details about list members, also in a pageable manner. It is used predominantly by administrators to manage and view list compositions and settings effectively.

```candid
// Retrieve lists, pageable
icrc_75_get_list_members_admin: (list: List, prev: opt ListItem, take: opt nat) -> query async vec ListItem;
```

#### List Queries

These functions are used to fetch detailed information regarding the members within the lists and the list structures themselves. They are vital for validating membership and understanding the hierarchical setup of nested lists.

##### icrc_75_get_list_lists

Facilitates the retrieval of sublists from a specific list, helping in understanding and navigating the structure of nested lists. Supports paging to manage larger structures effectively.

```candid
// Retrieve sublists from a list, pageable
icrc_75_get_list_lists: (list: List, prev: opt List, take: opt nat) -> query async vec List;
```

##### icrc_75_member_of

Retrieves memberships for a principal or list.

```candid
// Retrieve lists for a ListItem, pageable
icrc_75_member_of: (ListItem, prev: opt ListItem, take: opt nat) -> query async vec List;
```

##### icrc_75_is_member

Checks if specified identities are members of the lists they are queried against. This is a crucial function for validating access and permissions within the ecosystem, ensuring that operations are performed by authorized identities.

For the double vec List parameter, the inner vector is `or-ed` with its vector members and the outer vector members are `and-ed` together to allow for the query of mutual membership.

```candid
// Check membership of identities within lists
icrc_75_is_member: (vec AuthorizedRequestItem) -> query async vec bool;
```

#### Token Management Functions - Move to New ICRC or use verified credentials

These functions manage the lifecycle of membership tokens, which are used as a verifiable means to assert membership in lists, crucial for interactions across decentralized services.

##### icrc_75_request_token

Initiates a request for a membership token, representing an asynchronous operation where the token's preparation is handled in the background.

```candid
// Request a membership token for a list
icrc_75_request_token: (item: ListItem, list: List) -> async bool;
```

##### icrc_75_retrieve_token

Retrieves a previously requested membership token, providing a crucial link in ensuring that tokens are delivered securely and can be used by the requester to verify membership.

```candid
// Retrieve a prepared membership token for a list
icrc_75_retrieve_token: (item: ListItem, list: List) -> query async IdentityCertificate;
```

### icrc10_supported_standards

An implementation of ICRC-75 MUST implement the method `icrc10_supported_standards` as put forth in ICRC-10.

The result of the call MUST always have at least the following entries:

```candid
record { name = "ICRC-75"; url = "https://github.com/dfinity/ICRC/ICRCs/ICRC-75"; }
record { name = "ICRC-10"; url = "https://github.com/dfinity/ICRC/ICRCs/ICRC-10"; }
```


## Generic ICRC-7 Block Schema

An ICRC-75 block is defined as follows:
1. its `btype` field MUST be set to the op name that starts with `75`
2. it MUST contain a field `ts: Nat` which is the timestamp of when the block was added to the Ledger
3. it MUST contain a field `tx`, which
    1. MAY contain a field `memo: Blob` if specified by the user
    2. MAY contain a field `ts: Nat` if the user sets the `created_at_time` field in the request.

The `tx` field contains the transaction data as provided by the caller and is further refined for each the different update calls as specified below.

The block schemas for ICRC-75 are designed to record and track changes relating to list and identity management on the Internet Computer. Following is a detailed specification of each block type required for ICRC-75:

### Membership Change Block Schema

1. **`btype` field**: MUST be set to `"75memChange"`
2. **`tx` field**:
   1. MUST contain a field `list: Text` identifying the list affected.
   2. MAY contain `account: Array(Blob,?Blob)` specifying the acont of the item changed.
   2. May contain `dataItem: Value` specifying the Value of the item changed.
   2. May contain `listItem: Text - List - Text` specifying the Text or list of the list item changed.
   2. May contain `identityItem: Blob - Principal` specifying the Text or list of the list item changed.
   2. May contain `accountItemItem: Array(blob,blob` specifying the Text or list of the list item changed.
   3. MUST contain a field `change: Text` indicating "added" or "removed".
   4. MAY contain a field `changer: Identity - blob` identifying who made the change if applicable.

### List Creation Block Schema

1. **`btype` field**: MUST be set to `"75listCreate"`
2. **`tx` field**:
   1. MUST contain a field `list: Text` as the identifier for the newly created list.
   2. MUST contain a field `creator: Identity` as the Principal ID of the creator.
   3. MAY contain a field `initialAdmin: Identity - blob or List - text` containing initial list members.
   4. MAY contain a field `metadata: Value - Map` containing initial list metadata.

### List Modification Block Schema

1. **`btype` field**: MUST be set to `"75listModify"`
2. **`tx` field**:
   1. MUST contain a field `list: Text` as the identifier of the modified list.
   2. MAY contain a field `metadata: Value` detailing metadata key updates
   3. MAY contain a field `metadataDel: Text` detailing metadata removed
   4. MAY contain a field `newName: Text` detailing a new list name
   5. MUST contain a field `modifier: Identity` as the Principal ID of the modifier.

### Permission Change Block Schema

1. **`btype` field**: MUST be set to `"75permChange"`
2. **`tx` field**:
   1. MUST contain a field `list: Text` for the list where permissions are altered.
   2. MUST contain a field `targetIdentity: Identity- blob` for whose permissions have changed.
   3. MUST contain a field `newPermissions: Text` detailing the new permission set.
   4. MUST contain a field `previousPermissions: Text` showing previous permissions.
   5. MUST contain a field `changer: Identity - blob` identifying who made the changes.

### List Deletion Block Schema

1. **`btype` field**: MUST be set to `"75listDelete"`
2. **`tx` field**:
   1. MUST contain a field `list: Text` identifying the deleted list.
   2. MUST contain a field `deleter: Identity - blob` identifying who performed the deletion.

## Transaction Deduplication

Please reference [ICRC-7](https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md#other-aspects) for information about the approach to Transaction Deduplication.

## Security Considerations

This section highlights some selected areas crucial for security regarding the implementation of ledgers following this standard and Web applications using ledgers following this standard. Note that this is not exhaustive by any means, but rather points out a few selected important areas.

### Protection Against Denial of Service Attacks

Please reference [ICRC-7](https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md#other-aspects) for information about the approach to Protection Against Denial of Service Attacks.

### Protection Against Web Application Attacks

Please reference [ICRC-7](https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md#other-aspects) for information about the approach to Protection Against Web Application Attacks.


//todo:

- Add Errors when they are final
- icrc_75_get_list_permissions_admin : query (List, ?Permission, ?PermissionListItem, ?Nat) ->  async PermissionList;
  public type PermissionList = [PermissionListItem];

  public type PermissionListItem = (Permission, ListItem);

<!--
```candid ICRC-7.did +=
<<<Type definitions>>>

service : {
  <<<Methods>>>
}
```
-->
