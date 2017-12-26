// MARK: - Property Protocols

import Foundation

protocol AnyPropertyProtocol {
    associatedtype Root = Any
    associatedtype Value = Any
    associatedtype KP: AnyKeyPath
    //typealias Applicator = (Root, Value?) -> (Root, didChange: Bool)
    var key: KP { get }
    var value: Value { get }
    var applicator: (Any, Any?, Any?) -> (Any, didChange: Bool) { get set }
}

protocol PartialPropertyProtocol: AnyPropertyProtocol
where KP: PartialKeyPath<Root> {
    //typealias Applicator = (Root, Value?) -> (Root, didChange: Bool)
    
}

protocol PropertyProtocol: PartialPropertyProtocol
where KP: WritableKeyPath<Root, Value> {
    //typealias Applicator = (Root, Value?) -> (Root, didChange: Bool)
    //var applicator: (Root, Value?) -> (Root, didChange: Bool) { get }
}

// MARK: - Property Initializable

extension AnyPropertyProtocol {
    func apply(value: Value?, to: Root) -> (Root, didChange: Bool) {
        return applicator(to as! Root, value, nil) as! (Self.Root, didChange: Bool)
    }
    
    func apply<T>(value: Value?, to: Root, state: T? ...) -> (Root, didChange: Bool) {
        return applicator(to as! Root, value, state) as! (Self.Root, didChange: Bool)
    }
}

protocol PropertyInitializable {
    init?(with properties: [PartialProperty<Self>])
    init(clone: Self, with mutations: [PartialProperty<Self>])
    static var _blank: Self { get }
}

extension PropertyInitializable {
    var numberOfNonOptionalProperties: Int64 {
        return Mirror(reflecting: self).nonOptionalChildren.count
    }
    
    init?(with properties: [PartialProperty<Self>]) {
        var new = Self._blank
        var propertiesLeftToInit = new.numberOfNonOptionalProperties
        
        for property in properties {
            let value = property.value
            let (updated, didChange) = property.apply(value: value, to: new)
            if didChange {
                new = updated
                if !isOptional(value) { propertiesLeftToInit -= 1 }
            }
        }
        
        if propertiesLeftToInit == 0 { self = new; return } else { return nil }
    }
    
    init(clone: Self, with mutations: [PartialProperty<Self>]) {
        self = clone
        for mutation in mutations { (self, _) = mutation.apply(value: mutation.value, to: self) }
    }
}

extension Mirror {
    var nonOptionalChildren: Mirror.Children {
        let filtered = self.children.filter { child in
            guard let varName = child.label, let descendant = self.descendant(varName) else { return false }
            return !isOptional(descendant)
        }
        return Mirror.Children(filtered)
    }
}

func isOptional<T>(_ instance: T) -> Bool {
    guard let displayStyle = Mirror(reflecting: instance).displayStyle 
        else { return false }
    return displayStyle == .optional
}

// MARK: - Implementation

struct AnyProperty: AnyPropertyProtocol {
    typealias KP = AnyKeyPath
    typealias Root = Any
    typealias Value = Any
    
    private(set) var key: KP
    private(set) var value: Value
    var applicator: (Any, Any?, Any?) -> (Any, didChange: Bool)
    
    init<P>(_ base: P) where P: PropertyProtocol {
        self.value = base.value
        self.key = base.key as! AnyKeyPath
        self.applicator = base.applicator
    }
}

struct PartialProperty<R>: PartialPropertyProtocol {
    typealias Value = Any
    typealias KP = PartialKeyPath<R>
    typealias Root = R
    
    private(set) var key: PartialKeyPath<R>
    private(set) var value: Value
    var applicator: (Any, Any?, Any?) -> (Any, didChange: Bool)
    
    init<P>(_ base: P) where P: PropertyProtocol, P.Root == R {
        self.value = base.value
        self.key = base.key as! PartialKeyPath<Root>
        self.applicator = base.applicator
    }
}

struct Property<R, V>: PropertyProtocol {
    typealias Root = R
    typealias Value = V
    typealias KP = WritableKeyPath<R, V>
    
    private(set) var key: KP
    private(set) var value: Value
    var applicator: (Any, Any?, Any?) -> (Any, didChange: Bool)
    
    init(key: KP, value: Value) {
        self.key = key
        self.value = value
        self.applicator = {root, value, _ in 
            var instance: R = root as! R
            if let value = value as? V {
                instance[keyPath: key] = value
                return (instance, true)
            }
            return (instance, false)
        }
    }
    
    var partial: PartialProperty<Root> {
        return PartialProperty(self)
    }
    
    var any: AnyProperty {
        return AnyProperty(self)
    }
}

// MARK: - Tests

struct Test2 {
    private(set) var str1: String
    private(set) var int4: Int?
    private(set) var int5: Int?
}
extension Test2: PropertyInitializable {
    static var _blank = Test2(str1: "ERROR-NOT-SET", int4: nil, int5: nil)
}

// succeeds to init
var properties1: [PartialProperty<Test2>] = [
    Property(key: \Test2.str1, value: "asdf").partial,
    //Property(key: \Test2.int4, value: 1337).partial
]

// succeeds to init 
var properties2: [PartialProperty<Test2>] = [
    Property(key: \Test2.str1, value: "asdf").partial,
    Property(key: \Test2.int4, value: 1337).partial
]

// will fail to init because str1 is not optional
var properties3: [PartialProperty<Test2>] = [
    //Property(key: \Test2.str1, value: "asdf").partial,
    Property(key: \Test2.int4, value: 1337).partial
]

// succeeds to init 
var properties4: [PartialProperty<Test2>] = [
    Property(key: \Test2.str1, value: "asdf").partial,
    Property(key: \Test2.int4, value: nil).partial
]

let test1 = Test2(with: properties1)
assert(test1 != nil, "test1 should not be nil")
assert(test1!.str1 == "asdf", "test1.str1 should be 'asdf'")

let test2 = Test2(with: properties2)
assert(test2 != nil, "test2 should not be nil")
assert(test2!.str1 == "asdf", "test2.str1 should be 'asdf'")
assert(test2!.int4 == 1337, "test2.int4 should be 1337")

let test3 = Test2(with: properties3)
assert(test3 == nil, "test3 should be nil")

let test4 = Test2(clone: test2!, with: properties4)
assert(test4.str1 == "asdf", "test4.str1 should be 'asdf'")
assert(test4.int4 == nil, "test4.int4 should be nil")

let test5 = Test2(clone: test2!, with: properties3)
assert(test5.str1 == "asdf", "test5.str1 should be 'asdf'")
assert(test5.int4 == 1337, "test5.int5 should be 1337")

final class Foo {
    private(set) var bar: NSNumber = 0
    private(set) var baz: URLSession? = nil
}
extension Foo: PropertyInitializable {
    static var _blank: Foo = Foo()
}

var fooProps: [PartialProperty<Foo>] = [
    Property(key: \Foo.bar, value: 5).partial
]

let foo = Foo(with: fooProps)

// MARK: - Mockable

protocol Mockable: Codable, MockPropertyInitializable {
    //init?(in state: MockableState, default data: Self)
}
public enum MockableState {
    case canonical
}

// MARK: - Mockable Property

enum Mock<V> {
    typealias GeneratorInput = (initialValue: V?, index: Int?)
    typealias Generator = (GeneratorInput) throws -> V
    case singleValue(V)
    case iterate([V])
    case randomize([V])
    case generate(Generator, GeneratorInput)
}

protocol MockableProperty: PropertyProtocol where Root: Mockable {
    typealias Generator = Mock<Value>.Generator
    var mock: Mock<Value> { get }
    var generator: Generator { get }
}

extension MockableProperty {
    var generator: Generator {
        switch mock {
        case .singleValue(let value):
            return { _ in value }
        case .iterate(let values):
            return { input in 
                var index = input.index ?? 0
                if index >= values.count {
                    index = values.count % index
                } 
                return values[values.index(values.startIndex, offsetBy: index)]
            }
        case .randomize(let values):
            return { _ in // maybe use input.index for something here... ?
                let max = values.count - 1
                let rand = Int(arc4random_uniform(UInt32(max)))
                return values[values.index(values.startIndex, offsetBy: rand)]
            }
        case .generate(let generator, _):
            return generator
        }
    }
}

// MARK: - MockPropertyInitializable

protocol MockPropertyInitializable: PropertyInitializable {
    init?<T>(with properties: [PartialProperty<Self>], state: T? ...)
    init<T>(clone: Self, with mutations: [PartialProperty<Self>], state: T? ...)
}

extension MockPropertyInitializable {
    var numberOfNonOptionalProperties: Int64 {
        return Mirror(reflecting: self).nonOptionalChildren.count
    }
    
    init?<T>(with properties: [PartialProperty<Self>], state: T? ...) {
        var new = Self._blank
        var propertiesLeftToInit = new.numberOfNonOptionalProperties
        
        for property in properties {
            let value = property.value
            let (updated, didChange) = property.apply(value: value, to: new, state: state)
            if didChange {
                new = updated
                if !isOptional(value) { propertiesLeftToInit -= 1 }
            }
        }
        
        if propertiesLeftToInit == 0 { self = new; return } else { return nil }
    }
    
    init<T>(clone: Self, with mutations: [PartialProperty<Self>], state: T? ...) {
        self = clone
        for mutation in mutations { (self, _) = mutation.apply(value: mutation.value, to: self, state: state) }
    }
}

// MARK: - Mock Property

struct MockProperty<R: Mockable, V>: MockableProperty {
    typealias Root = R
    typealias Value = V
    typealias KP = WritableKeyPath<R, V>
    
    struct State {
        enum ArraySelectionMethod {
            case iterative
            case random
        }
        
        let iteration: Int
        let `default`: Value
        let arraySelectionMethod: ArraySelectionMethod
    }
    
    private(set) var key: KP
    var value: Value { return try! generator((nil, nil)) }
    var applicator: (Any, Any?, Any?) -> (Any, didChange: Bool)
    private(set) var mock: Mock<Value>
    
    init(key: KP, value: Value) {
        self.init(key: key, mock: .singleValue(value))
    }
    
    init(key: KP, generator: @escaping Mock<Value>.Generator, input: Mock<Value>.GeneratorInput) {
        self.init(key: key, mock: .generate(generator, input))
    }
    
    init(key: KP, possibleValues: [Value], shouldRandomize: Bool = false) {
        var mock: Mock<Value> = shouldRandomize ? .randomize(possibleValues) : .iterate(possibleValues)
        self.init(key: key, mock: mock)
    }
    
    init(key: KP, mock: Mock<Value>) {
        self.key = key
        self.mock = mock
        self.applicator = { root, value, state in
            var instance: Root = root as! R
            switch (value, state) {
            case let (value, _) as (Value, Any?):
                instance[keyPath: key] = value
                return (instance, true)
            case let (values, state) as ([Value], [Int]):
                guard !state.isEmpty else {
                    return (instance, false)
                }
                instance[keyPath: key] = values[state[0]]
                return (instance, true)
            case let (values, state) as ([Value], [Bool]):
                guard !state.isEmpty else {
                    return (instance, false)
                }
                let shouldRandomize = state[0]
                switch shouldRandomize {
                case true:
                    let index = Int(arc4random_uniform(UInt32(values.count - 1)))
                    instance[keyPath: key] = values[index]
                case false:
                    instance[keyPath: key] = values[0]
                }
                return (instance, true)
            case let (valueGenerator, state) as (Mock<Value>.Generator, [(Mock<Value>.GeneratorInput)]):
                guard !state.isEmpty else {
                    return (instance, false)
                }
                switch mock {
                case .generate(let gen, let input):
                    do {
                        instance[keyPath: key] = try gen(input)
                        return (instance, true)
                    } catch {
                        print(error)
                        return (instance, false)
                    }
                default:
                    return (instance, false)
                }
            default:
                return (instance, false)
            }
        }
    }
    
    var partial: PartialProperty<Root> {
        return PartialProperty(self)
    }
    
    var any: AnyProperty {
        return AnyProperty(self)
    }
}

// MARK: - Bug:

infix operator +: AdditionPrecedence
infix operator ~: AdditionPrecedence

extension Array where Element == PartialProperty<Any?> {
    static func + <Root, Value>(left: Array<PartialProperty<Root>>, right: (WritableKeyPath<Root, Value>, Value)) -> Array<PartialProperty<Root>>
    { 
        var new = left
        print(left.count)
        let partial = (Property<Root, Value>(key: right.0, value: right.1)).partial
        new.append(partial)
        print(new.count)
        return new
    }
    
    static func ~ <Root, Value>(left: Array<PartialProperty<Root>>, right: (WritableKeyPath<Root, Value>, Value)) -> Array<PartialProperty<Root>>
    { 
        var new = left
        print(left.count)
        let partial = (Property<Root, Value>(key: right.0, value: right.1)).partial
        new.append(partial)
        print(new.count)
        return new
    }
}

struct Zag: PropertyInitializable {
    private(set) var a: Int
    private(set) var b: String
    private(set) var c: Double?
    static var _blank: Zag {
        return Zag(a: 1, b: "1", c: 1.0)
    }
} 

var p: [PartialProperty<Test2>] = []
//p = p + (\Test2.str1, "asdf") + (\Test2.int4, 1337) //BUG: does not compile
p = p + (\Test2.str1, "asdf") ~ (\Test2.int4, 1337) // works lol
p = [] + (\Test2.str1, "asdf") ~ (\Test2.int4, 1337) + (\Test2.int5, 999) // 

let testy = Test2.init(with: p)

let z: [PartialProperty<Zag>] = [] + (\.a, 2) ~ (\.b, "2") + (\.c, 2.0) // works
//let z: [PartialProperty<Zag>] = [] + (\.a, 2) + (\.b, "2") + (\.c, 2.0) //doesn't work

let testz = Zag(with: z)
assert(testz != nil)
assert(testz!.a == 2)
assert(testz!.b == "2")
assert(testz!.c == 2.0)

// MARK: - Mockables test

struct Mag: Mockable {
    private(set) var a: Int
    private(set) var b: String
    private(set) var c: Double?
    static var _blank: Mag {
        return Mag(a: 1, b: "10", c: 1.0)
    }
}

infix operator =>
infix operator ~>

extension WritableKeyPath {
    static func => (left: WritableKeyPath<Root, Value>, right: @autoclosure @escaping () throws -> Value) throws -> PartialProperty<Root> {
        return Property<Root, Value>(key: left, value: try right()).partial
    }
}

extension WritableKeyPath where Root: Mockable {
    //static func => (left: WritableKeyPath<Root, Value>, right: @escaping Mock<Value>.Generator) throws -> PartialProperty<Root> {
    //return MockProperty<Root, Value>(key: left, generator: right).partial
    //}
    
    static func => (left: WritableKeyPath<Root, Value>, right: (generator: Mock<Value>.Generator, input: Mock<Value>.GeneratorInput)) throws -> PartialProperty<Root> {
        return MockProperty<Root, Value>(key: left, generator: right.generator, input: right.input).partial
    }
}

typealias GeneratorInput<V> = (initialValue: V?, index: Int?)

func gen<V: StringProtocol> (_ input: GeneratorInput<V>) throws -> V { 
    let val = "\(input.initialValue ?? "2")"
    let index = input.index ?? 0
    return val + "\(index)" as! V
}

var m: [PartialProperty<Mag>] = try! [
    \.a => 2,
    \.b => gen((nil, nil)),
    \.c => nil
]
//m += (\.b, generator: gen)
//m += (\.c, [1.0, 2.0, 2.5], shouldRandomize: true)

let magtest1 = try! Mag(with: [
    \.a => 2,
    \.b => gen((nil, nil)),
    \.c => nil
    ]
) 

let magtest2 = try! Mag(with: [
    \.a => 2,
    \.b => (generator: gen, input: (initialValue: nil, index: 2)),
    \.c => nil
    ]
) 

extension Mag {
    
    /// Custom property initter!
    
}
