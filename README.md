# rain.lib.typecast

Common casts and conversions between Solidity types that aren't natively possible
due to the Solidity compiler enforcing constraints or them being ambiguous and/or
unsafe generally.

In this context a cast moves between Solidity types without changing the binary
data, it merely forces the type system to treat some type as another. For example
we have functions here to convert `uint256[]` to `bytes32[]` without changing any
of the internal values of the arrays.

Conversions involve mutations to the binary data in the process of moving between
types. For example, moving from `uint256[]` to `bytes` involves mutating the
length of the collection even if the binary data values are unchanged.

Casting to a type narrower than a 32 byte word is where "without changing the
binary data" stops being incidental and starts being load bearing. Solidity
holds a value narrower than a word zero extended in memory, but a cast writes
nothing, so it cannot clear the high bits of a word that has them set.
`LibCast.asAddressesArray` is the only cast here that narrows; its NatSpec
documents which consumers observe those bits (assembly reads of the elements)
and which do not (everything the compiler generates, including storage writes,
`mapping` keys, hashing and the external ABI boundary). A caller that needs the
high bits gone needs a conversion - a copy, or an explicit mask - and not a
cast.
