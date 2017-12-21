// 

// MARK: - Property Protocols

import Foundation

protocol AnyPropertyProtocol {
    associatedtype Root = Any
    associatedtype Value = Any
    associatedtype KP: AnyKeyPath
    //typealias Applicator = (Root, Value?) -> (Root, didChange: Bool)
    var key: KP { get }
    var value: Value { get }
    var applicator: (Any, Any?) -> (Any, didChange: Bool) { get set }
}

protocol PartialPropertyProtocol: AnyPropertyProtocol
where KP: PartialKeyPath<Root> {
    //typealias Applicator = (Root, Value?) -> (Root, didChange: Bool)
    
}

extension AnyPropertyProtocol {
    func apply(value: Value?, to: Root) -> (Root, didChange: Bool) {
        return applicator(to as! Root, value) as! (Self.Root, didChange: Bool)
    }
}

protocol PropertyProtocol: PartialPropertyProtocol
where KP: WritableKeyPath<Root, Value> {
    //typealias Applicator = (Root, Value?) -> (Root, didChange: Bool)
    //var applicator: (Root, Value?) -> (Root, didChange: Bool) { get }
}

// MARK: - Property Initializable

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
    var applicator: (Any, Any?) -> (Any, didChange: Bool)
    
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
    var applicator: (Any, Any?) -> (Any, didChange: Bool)
    
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
    var applicator: (Any, Any?) -> (Any, didChange: Bool)
    
    init(key: KP, value: Value) {
        self.key = key
        self.value = value
        self.applicator = {
            var instance: R = $0 as! R
            if let value = $1 as? V {
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

// MARK: - Mocking

protocol Mockable: Codable, PropertyInitializable {
    //init?(in state: MockableState, default data: Self)
}
public enum MockableState {
    case canonical
}

enum Mock<V> {
    typealias GeneratorInput = (initialValue: V?, index: Int?)
    typealias Generator = (GeneratorInput) throws -> V
    case singleValue(V)
    case iterate([V])
    case randomize([V])
    case generate(Generator)
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
        case .generate(let generator):
            return generator
        }
    }
}

struct MockProperty<R: Mockable, V>: MockableProperty {
    typealias Root = R
    typealias Value = V
    typealias KP = WritableKeyPath<R, V>
    
    private(set) var key: KP
    var value: Value { return try! generator((nil, nil)) }
    var applicator: (Any, Any?) -> (Any, didChange: Bool)
    private(set) var mock: Mock<Value>
    
    init(key: KP, value: Value) {
        self.init(key: key, mock: .singleValue(value))
    }
    
    init(key: KP, generator: @escaping Generator) {
        self.init(key: key, mock: .generate(generator))
    }
    
    init(key: KP, possibleValues: [Value], shouldRandomize: Bool = false) {
        var mock: Mock<Value> = shouldRandomize ? .randomize(possibleValues) : .iterate(possibleValues)
        self.init(key: key, mock: mock)
    }
    
    init(key: KP, mock: Mock<Value>) {
        self.key = key
        self.mock = mock
        self.applicator = {
            var instance: Root = $0 as! R
            if let value = $1 as? Value {
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

extension Array {
    init<R>(_ properties: (key: PartialKeyPath<R>, value: Any?) ...) where Element == PartialProperty<R> {
        var new = [PartialProperty<R>]()
        func add<V>(_ prop: (key: PartialKeyPath<R>, value: Any?), _ value: V) {
            print(V.self)
            //new.append(Property(key: prop.key as! WritableKeyPath<R, V>, value: value).partial)
        }
        properties.forEach {prop in 
            add(prop, prop.value)
        }
        self = new
    }
}

infix operator +=: AssignmentPrecedence
infix operator +: AdditionPrecedence
infix operator ~: AdditionPrecedence
infix operator +=>: AssignmentPrecedence

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
    
    static func +=> <Root, Value>(left: inout Array<PartialProperty<Root>>, right: (WritableKeyPath<Root, Value>, Value))
    { 
        var new = left
        print(left.count)
        let partial = (Property<Root, Value>(key: right.0, value: right.1)).partial
        new.append(partial)
        print(new.count)
    }
}

extension Array where Element == PartialProperty<Any?> {
    static func += <Root: Mockable, Value>(left: inout Array<PartialProperty<Root>>, right: (WritableKeyPath<Root, Value>, Value))
    { 
        left.append((MockProperty<Root, Value>(key: right.0, value: right.1)).partial)
    }
    
    static func += <Root: Mockable, Value>(left: inout Array<PartialProperty<Root>>, right: (WritableKeyPath<Root, Value>, [Value], shouldRandomize: Bool))
    { 
        left.append((MockProperty<Root, Value>(key: right.0, possibleValues: right.1, shouldRandomize: right.shouldRandomize)).partial)
    }
    
    static func += <Root: Mockable, Value>(left: inout Array<PartialProperty<Root>>, right: (WritableKeyPath<Root, Value>, generator: Mock<Value>.Generator))
    { 
        left.append((MockProperty<Root, Value>(key: right.0, generator: right.generator)).partial)
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

struct Mag: Mockable {
    private(set) var a: Int
    private(set) var b: String
    private(set) var c: Double?
    static var _blank: Mag {
        return Mag(a: 1, b: "1", c: 1.0)
    }
}

let gen: Mock<String>.Generator = { input in
    let val = "\(input.initialValue ?? "new")"
    let index = input.index ?? 0
    return val + "\(index)"
}

var m: [PartialProperty<Mag>] = []
m += (\.a, 2) // use = instead of ,
m += (\.b, generator: gen)
m += (\.c, [1.0, 2.0, 2.5], shouldRandomize: true)

let magtest1 = Mag(with: m) 

extension Mag {
    
    /// Custom property initter!
    
}
