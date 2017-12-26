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
    func apply(value: Value?, to root: Root) -> (Root, didChange: Bool) {
        return applicator(root as! Root, value, nil) as! (Self.Root, didChange: Bool)
    }
}

protocol PropertyInitializable {
    init?(_ properties: [PartialProperty<Self>])
    init(clone: Self, with mutations: [PartialProperty<Self>])
    static var _blank: Self { get }
}

extension PropertyInitializable {
    var numberOfNonOptionalProperties: Int64 {
        return Mirror(reflecting: self).nonOptionalChildren.count
    }
    
    init?(_ properties: [PartialProperty<Self>]) {
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
    
    init?(_ properties: PartialProperty<Self>...) {
        self.init(properties)
    }
    
    init(clone: Self, with mutations: [PartialProperty<Self>]) {
        self = clone
        for mutation in mutations { (self, _) = mutation.apply(value: mutation.value, to: self) }
    }
    
    init(clone: Self, with mutations: PartialProperty<Self>...) {
        self.init(clone: clone, with: mutations)
    }
}

extension Mirror {
    var nonOptionalChildren: Mirror.Children {
        print(self)
        print(self)
        let filtered = self.children.filter { child in
            print(child)
            guard let varName = child.label, let descendant = self.descendant(varName) else { return false }
            print(descendant)
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
    
    //todo: add the below to protocols?
    
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

let test1 = Test2(properties1)
assert(test1 != nil, "test1 should not be nil")
assert(test1!.str1 == "asdf", "test1.str1 should be 'asdf'")

let test2 = Test2(properties2)
assert(test2 != nil, "test2 should not be nil")
assert(test2!.str1 == "asdf", "test2.str1 should be 'asdf'")
assert(test2!.int4 == 1337, "test2.int4 should be 1337")

let test3 = Test2(properties3)
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

let foo = Foo(fooProps)

// MARK: - Sugar

infix operator =>
infix operator ~> // todo: make any

extension WritableKeyPath {
    static func => (left: WritableKeyPath<Root, Value>, right: @autoclosure @escaping () throws -> Value) throws -> PartialProperty<Root> {
        return Property<Root, Value>(key: left, value: try right()).partial
    }
}

// MARK: - Mockable

protocol Mockable: Codable, PropertyInitializable {
    //init?(in state: MockableState, default data: Self)
}
public enum MockableState {
    case canonical
}

// MARK: - Mockable Property

struct Mock<Value>: PropertyInitializable {
    indirect enum CreationMethod {
        case none
        case single(Value)
        case iterate([Value])
        case randomize([Value])
        case generate(Generator, CreationMethod)
    }
    typealias Generator = (CreationMethod) -> Value
    private(set) var iteration: Int
    private(set) var `default`: Value?
    private(set) var creationMethod: CreationMethod
    static var _blank: Mock<Value> { return Mock<Value>(iteration: 0, default: nil, creationMethod: .none) }
}

protocol MockableProperty: PropertyProtocol where Root: Mockable {
    var mock: Mock<Value> { get }
}

extension MockableProperty {
    var value: Value {
        get {
            switch mock.creationMethod {
            case .none:
                fatalError()
            case .single(let value):
                return value
            case .iterate(let values):
                var index = mock.iteration
                if index >= values.count {
                    index = values.count % index
                } 
                return values[values.index(values.startIndex, offsetBy: index)]
            case .randomize(let values):
                let max = values.count - 1
                let rand = Int(arc4random_uniform(UInt32(max)))
                return values[values.index(values.startIndex, offsetBy: rand)]
            case .generate(let generator, let creationMethod):
                return generator(creationMethod)
            }
        }
        set {
            // do nothing. this is just to let us use the default init
        }
    }
    
    func apply(mock: Mock<Value>, to root: Root) -> (Root, didChange: Bool) {
        return applicator(root as! Root, mock, nil) as! (Self.Root, didChange: Bool)
    }
}

// MARK: - Mock Property

struct MockProperty<R: Mockable, V>: MockableProperty {
    typealias Root = R
    typealias Value = V
    typealias KP = WritableKeyPath<R, V>
    
    private(set) var key: KP
    private(set) var mock: Mock<Value>
    
    var applicator: (Any, Any?, Any?) -> (Any, didChange: Bool)
    
    init(key: KP, value: Value) {
        let mock: Mock<Value> = try! Mock<Value>(
            \.creationMethod => .single(value)
            )!
        self.init(key: key, mock: mock)
    }
    
    init(key: KP, possibleValues: [Value], shouldRandomize: Bool = false, iteration: Int) {
        let mock: Mock<Value> = try! Mock<Value>(
            \.iteration => iteration,
            \.creationMethod => (shouldRandomize 
                ? .randomize(possibleValues) 
                : .iterate(possibleValues))
            )!
        self.init(key: key, mock: mock)
    }
    
    init(key: KP, generator: @escaping Mock<Value>.Generator, creationMethod: Mock<Value>.CreationMethod) {
        let mock: Mock<Value> = try! Mock<Value>(
            \.creationMethod => .generate(generator, creationMethod)
            )!
        self.init(key: key, mock: mock)
    }
    
    init(key: KP, mock: Mock<Value>) {
        self.mock = mock
        self.key = key
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

let testy = Test2.init(p)

let z: [PartialProperty<Zag>] = [] + (\.a, 2) ~ (\.b, "2") + (\.c, 2.0) // works
//let z: [PartialProperty<Zag>] = [] + (\.a, 2) + (\.b, "2") + (\.c, 2.0) //doesn't work

let testz = Zag(z)
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

let magtest1 = try! Mag(
    \.a => 2,
    \.b => gen((nil, nil)),
    \.c => nil
) 

assert(magtest1 != nil)
assert(magtest1?.a == 2)
assert(magtest1?.b == "20")
assert(magtest1?.c == nil)

extension WritableKeyPath where Root: Mockable {
    static func => (left: WritableKeyPath<Root, Value>, right: Mock<Value>) throws -> PartialProperty<Root> {
        return MockProperty<Root, Value>(key: left, mock: right).partial
    }
}

var magtest2 = [Mag]()

for i in 0...5 {
    magtest2.append((try! Mag(
        \.a => 2,
        \.b => Mock(iteration: i, default: nil, creationMethod: .iterate(["a", "b", "c", "d", "e"])),
        \.c => nil
        ))!
    )
}

let letters = ["a", "b", "c", "d", "e"]

for i in 0...4 {
    assert(magtest2[i].b == letters[i])
}

extension Mag {
    // todo
    /// Custom property initter!
}

struct Hat {
    //let a: Int // breaks PropertyInitializable if uncommented, 
    // since let cannot be set via keypaths
    
    //private var b: Int // breaks PropertyInitializable if uncommented, 
    // since private var cannot be set via keypaths
    
    //let d = 1 // breaks PropertyInitializable if uncommented, 
    // since let cannot be set via keypaths, 
    // and there is no way to check if it has a default value
    
    //private var e = 1 // breaks PropertyInitializable if uncommented, 
    // since private var cannot be set via keypaths, 
    // and there is no way to check if it has a default value
    
    //private(set) var f = 1 // breaks PropertyInitializable if uncommented, 
    // since f has a default value, 
    // and private(set) is externally immutable once set
    
    private(set) var c: Int
    
    var g = 1 // must be set again for PropertyInitializable init to succeed
    
    var h: Int
}

extension Hat: PropertyInitializable {
    static var _blank: Hat {
        return Hat(c: 1, g: 1, h: 1)
    }
}

do {
    let testHat = try Hat(
        //\.a => 2, // breaks if uncommented, as expected since a is let
        //\.b => 2, // breaks if uncommented, as expected since b is private
        //\.d = 2, // breaks if uncommented, as expected since d is let 
        //\.e = 2, // breaks if uncommented, as expected since e is private
        //\.f = 2, // breaks if uncommented, as expected since f has a default value, and private(set) is externally immutable once set
        \.c => 2,
        \.g => 2,
        \.h => 2
    )
    assert(testHat != nil)
} catch {
    print(error)
}
