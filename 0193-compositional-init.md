# Feature name

* Proposal: [SE-0193](0193-compositional-init.md)
* Authors: [Jonathan Gilbert](https://github.com/gistya)
* Review Manager: TBD
* Status: **Awaiting implementation**

*During the review process, add the following fields as needed:*

* Implementation: [apple/swift#NNNNN](https://github.com/apple/swift/pull/NNNNN)
* Decision Notes: [Rationale](https://lists.swift.org/pipermail/swift-evolution/), [Additional Commentary](https://lists.swift.org/pipermail/swift-evolution/)
* Bugs: [SR-NNNN](https://bugs.swift.org/browse/SR-NNNN), [SR-MMMM](https://bugs.swift.org/browse/SR-MMMM)
* Previous Revision: [1](https://github.com/apple/swift-evolution/blob/...commit-ID.../proposals/NNNN-filename.md)
* Previous Proposal: [SE-XXXX](XXXX-filename.md)

## Introduction

Introduces opt-in protocols that allow the initialization of an adopting type in two new and useful ways:
- init from a collections of typesafe key-value *Property* objects
- shallow copy mutated according to accompanying collection of *Property* overrides

Note: the initial PR for this proposal does not change the compiler or SIL in any way. However, I hope the community would assist with such optimizations should this gain support, since without deeper changes to allow using KeyPath-based assignment to immutable variables during initialization, the implementation of this proposal must rely on using pre-initialized `private(set)` properties. 

Swift-evolution thread: [Discussion thread topic for that proposal](https://lists.swift.org/pipermail/swift-evolution/)

## Motivation

Using immutable types is core to functional programming, as immutability carries many benefits for safety, performance, testing, state management, and comprehensibility. However in Swift 4, the benefits of immutability include neither:
- "ease of making a new copy that's different only at one property without lots of boilerplate" nor 
- "initializing an object from a typesafe set of key-value pairs in one line of code."

[The current workaround to avoid boilerplate](https://stackoverflow.com/questions/38331277/how-to-copy-a-struct-and-modify-one-of-its-properties-at-the-same-time) is actually to use mutable types. 

This proposal aims to fix that by adding simple, clear, Swifty syntax for the creation of an instance of an immutable type from a set of properties with optional clone argument.

The initial proposal introduces the following syntax, given a type `Foo` with properties `bar: String`, `baz: Double`, `quux: Int?`:

    let foo1 = Foo(bar: "one", baz: 1.0, quux: nil)
    let foo2 = Foo(clone: foo1, mutating: [Property(\.quux, 42).partial]) // returns non-optional Foo

    let fooProperties: [PartialProperty<Foo>] = [
        Property(\.bar, "two").partial, 
        Property(\.baz, 2.0).partial, 
        Property(\.quux, nil).partial
    ]

    let foo3 = Foo(with: fooProperties) // returns optional Foo (failable init)

Implementing this proposal lets Swift match and even surpass similar features in other languages.

Similar features in other static, typesafe, functional languages that allow the initialization of a new instance via cloning with property overrides:
- Haskell's' [default values in records](https://wiki.haskell.org/Default_values_in_records): `newRecord = fooDefault { quux = 42 }` makes a clone where `quux` is overridden but the `bar` and `baz` properties are copied from `fooDefault`
- OCaml features [functional updates](https://realworldocaml.org/v1/en/html/records.html#functional-updates): `let newRecord foo =
{ foo with quux = 42 };;`
- A Successor-ML proposal for [functional record update proposal](http://sml-family.org/successor-ml/OldSuccessorMLWiki/Functional_record_extension_and_row_capture.html) suggests: `foo {defaults where quux=42}`

Some dynamic languages also support this concept:
- Elm features [updating records](http://elm-lang.org/docs/records#updating-records): `newRecord = { foo | quux = 42 }`
- An ECMAScript 7 proposal for [object spread initializer](https://github.com/tc39/proposal-object-rest-spread/blob/master/Spread.md) suggests: `let fooWithOverrides = { quux: 42 , ...foo };` etc.



to make a new instance of some immutable object. This is common when manipulating data originating from a webservice. 


Another workaround is to use a memberwise initializer and pass in the properties one by one from the first object to the new clone, and introduce the new values in certain arguments. This is not clean.

Some languages such as ECMA Script 6 have taken the idea of destructuring initialization a bit further, where 

## Proposed solution

Describe your solution to the problem. Provide examples and describe
how they work. Show how your solution is better than current
workarounds: is it cleaner, safer, or more efficient?

## Detailed design

Describe the design of the solution in detail. If it involves new
syntax in the language, show the additions and changes to the Swift
grammar. If it's a new API, show the full API and its documentation
comments detailing what it does. The detail in this section should be
sufficient for someone who is *not* one of the authors to be able to
reasonably implement the feature.

## Source compatibility

Relative to the Swift 3 evolution process, the source compatibility
requirements for Swift 4 are *much* more stringent: we should only
break source compatibility if the Swift 3 constructs were actively
harmful in some way, the volume of affected Swift 3 code is relatively
small, and we can provide source compatibility (in Swift 3
compatibility mode) and migration.

Will existing correct Swift 3 or Swift 4 applications stop compiling
due to this change? Will applications still compile but produce
different behavior than they used to? If "yes" to either of these, is
it possible for the Swift 4 compiler to accept the old syntax in its
Swift 3 compatibility mode? Is it possible to automatically migrate
from the old syntax to the new syntax? Can Swift applications be
written in a common subset that works both with Swift 3 and Swift 4 to
aid in migration?

## Effect on ABI stability

Does the proposal change the ABI of existing language features? The
ABI comprises all aspects of the code generation model and interaction
with the Swift runtime, including such things as calling conventions,
the layout of data types, and the behavior of dynamic features in the
language (reflection, dynamic dispatch, dynamic casting via `as?`,
etc.). Purely syntactic changes rarely change existing ABI. Additive
features may extend the ABI but, unless they extend some fundamental
runtime behavior (such as the aforementioned dynamic features), they
won't change the existing ABI.

Features that don't change the existing ABI are considered out of
scope for [Swift 4 stage 1](README.md). However, additive features
that would reshape the standard library in a way that changes its ABI,
such as [where clauses for associated
types](https://github.com/apple/swift-evolution/blob/master/proposals/0142-associated-types-constraints.md),
can be in scope. If this proposal could be used to improve the
standard library in ways that would affect its ABI, describe them
here.

## Effect on API resilience

API resilience describes the changes one can make to a public API
without breaking its ABI. Does this proposal introduce features that
would become part of a public API? If so, what kinds of changes can be
made without breaking ABI? Can this feature be added/removed without
breaking ABI? For more information about the resilience model, see the
[library evolution
document](https://github.com/apple/swift/blob/master/docs/LibraryEvolution.rst)
in the Swift repository.

## Alternatives considered

Describe alternative approaches to addressing the same problem, and
why you chose this approach instead.

