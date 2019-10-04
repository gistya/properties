# Feature name

* Proposal: [SE-0XXX](0XXX-compositional-init.md)
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

This proposal introduces an opt-in protocol, `PropertyInitializable`, which provides two new init methods:
- failable init from a collections of extensible, typesafe keypath-value *Property* objects
- non-failable init to clone from another instance, mutating select properties

The name “compositional init” means that this proposal allows the state of an object to be assembled *compositionally* from sets of properties (including another instance). Compositional initialization allows mutations to be encapsulated in a clear, type-safe way.

This proposal addresses the problems that motivated Chris Lattner’s excellent proposal, [SE-0018](https://github.com/apple/swift-evolution/blob/master/proposals/0018-flexible-memberwise-initialization.md), but in a different way. Hopefully compositional init can serve as the implementation of SE-0018, which unfortunately got tabled due lack of ABI impact.

I believe this may also address the desires expressed in the Swift Evolution discussion thread ["Record initialization and destructuring syntax"](https://forums.swift.org/t/record-initialization-and-destructuring-syntax/16631). I do not see any follow-up proposal for that, so I am assuming nothing has come of it yet. 

Swift-evolution thread: [Discussion thread topic for that proposal](https://lists.swift.org/pipermail/swift-evolution/)

## Motivation

Immutability carries many benefits including thread safety, simplification of state management, and improved code comprehensibility. It’s what makes functional programming so functional, which helps create unit-testable code. 

However, in Swift 5, the benefits of immutability include neither:

(1) - "ease of making a copy that differs from the original in a subset of its properties — without lots of boilerplate,” nor (more generally),

(2) - "initializing an object from a collection or set of collections of its properties in one line of code."

The desire for no boilerplate and greater flexibility when initializing and cloning immutable types motivated this proposal. 

### Use Cases

A growing movement exists to [use immutable models to handle data responses from the web in Swift applications](https://academy.realm.io/posts/slug-peter-livesey-managing-consistency-immutable-models/). 

My specific use case involves mocking a web service in Swift, where we simulate the server’s responses by changing a few properties of an immutable data model object from a canonical example. However, in addition to satisfying that one need, I found that this style of initialization allows for many other useful patterns that simplify code and improve clarity. 

### Detail of the Motivation

Chris Lattner’s SE-0018 proposal notes that in current solutions for (1), “initialization scales with M x N complexity (M members, N initializers).” I call this the “boilerplate cost” — measured on the “big B” scale. Indeed, [one advised workaround](https://stackoverflow.com/questions/38331277/how-to-copy-a-struct-and-modify-one-of-its-properties-at-the-same-time) for (1) involves going from B(M*N) down to B(2M), where M is the number of different properties to be supported for mutation during cloning. 

**Compositional Init**, on the other hand, provides B(0) for copying an immutable object while changing some arbitrary selection of its properties, and also provides a B(0) solution for problem (2).

### How Other Languages Have Solved (1)

Other languages have good solutions for (1) that are similar to compositional init, but none seem to solve (2) the way CI can.

Some examples of static, typesafe, functional languages that allow the initialization of a new instance via cloning with property overrides:
- Haskell’s’ [default values in records](https://wiki.haskell.org/Default_values_in_records): `newRecord = fooDefault { quux = 42 }` makes a clone where `quux` is overridden but the `bar` and `baz` properties are copied from `fooDefault`
- OCaml’s [functional updates](https://realworldocaml.org/v1/en/html/records.html#functional-updates): `let newRecord foo =
{ foo with quux = 42 };;`
- A Successor-ML proposal for [functional record update proposal](http://sml-family.org/successor-ml/OldSuccessorMLWiki/Functional_record_extension_and_row_capture.html) suggests: `foo {defaults where quux=42}`

Dynamic languages have been slower to embrace immutability, but support for this concept is growing:
- Elm features [updating records](http://elm-lang.org/docs/records#updating-records): `newRecord = { foo | quux = 42 }`
- An ECMAScript 7 proposal for [object spread initializer](https://github.com/tc39/proposal-object-rest-spread/blob/master/Spread.md) suggests: `let fooWithOverrides = { quux: 42 , ...foo };` etc. 
- An ECMAScript 6 [library for clone + mutate](https://www.npmjs.com/package/transmutable)

## Proposed solution

Compositional init solves both (1) and (2) by adding simple, clear, Swifty syntax for the initializing an immutable instance from a set of typesafe properties and an optional clone argument. Because this proposal is based purely upon Swift 4/5’s wonderful KeyPath and Mirror types, we get all the type safety and access restriction guarantees that they already carry. 

Traditional memberwise init:

    let fool: Foo = Foo(bar: “one”, baz: 1.0, quux: nil)

Compositional init cloning `fool` and mutating its `quux` property:

    let food: Foo = Foo(clone: fool, mutating: \.quux => 42)

Compositional init failably initializing `foom` from an array of properties:

    let properties: [PartialProperty<Foo>] = 
    [
       \.bar  => “two”, 
       \.baz  =>  2.0, 
       \.quux =>  nil
    ]

    let foom: Foo? = Foo(properties)

Compositional init failably initializing `foom` from variadic property arguments:

    let foom: Foo? = Foo(\.bar => “two”, \.baz => 2.0, \.quux => nil)

As a result of being based on `WritableKeyPath<Root, Value>`, the declaration `\Foo.bar => “two”` will fail to compile if the property `Foo.bar` is any of the following:
- not accessible in the current scope
- not writable in the current scope
- not the same type as the value being paired with it
- non-existent

The only drawback to the initial PR implementing this proposal is that immutability under compositional init requires using `private(set) var` on any properties that are to be represented within init compositions. Since WritableKeyPaths are pointers under the hood, they cannot currently be used inside an init method on any member of `self` unless that member is already initialized. So, while keypaths to uninitialized `let` variables are considered Writable by the compiler, bizarrely, they cannot actually be used for writing. I hope this is just a bug, and the core team would be amenable to fixing it.

Otherwise, we may just look on the bright side: since compositional init is opt-in at the type level, we might feel it should be opt-in at the property level, too. Under the initial PR, it effectively is, since a property can `opt-out` by being a `let` or being a `private(set) var` with a default value.

## Detailed design

This proposal introduces the following protocols:
- AnyPropertyProtocol
- PartialPropertyProtocol
- PropertyProtocol
- PropertyInitializable

Accompanying these, we introduce implementations:
- AnyProperty
- PartialProperty<Root>
- Property<Root, Value>

This proposal introduces the “partially type-erasing lazy assignment operator” `=>`, which returns a `PartialProperty<Root, Value>` from a `WritableKeyPath<Root,Value>` on the left side, and on the right, an `@autoclosure @escaping` that can accept either:
- a `Value` object, or
- a function returning `Value` that will be lazily executed only at init.

## Source compatibility

Aside from any naming collisions (sorry), it should also have zero effect on source code compatibility.

## Effect on ABI stability

The initial PR for this proposal should not impact ABI stability, as far as I can tell. 

However, if the final form of this proposal involves changes to the compiler (for example, if the compiler is updated to allow using KeyPath-based assignment to `let` variables during initialization) then perhaps there could be an effect on ABI stability. I doubt it though, since this seems like an additive feature that should be able to be accomplished in an stable way.

## Effect on API resilience

Compositional init should play nice, but I will leave it to the experts as to what aspects are suitable to make `@inlineable`.

## Alternatives considered

One alternative is to simply avoid immutable “set once at init” style properties, and instead use `var` for any properties you might need to change. The pattern is then to “immutable-ize” the root type by using `let` at instantiation, as in:

    struct Foo {
        var bar: String 
        var baz: Double
        var quux: Int?
    }

    let fool = Foo(bar: “one”, baz: 1.0, quux: nil) // hah! can’t change me now!
    
    var food = fool 
    food.quux = 42
    let foom = food // immutable once again.

That workaround is not great because there is nothing to prevent mistakes or abuses.

As well there was discussion on the aforementioned thread on destructuring, to which you may refer.
