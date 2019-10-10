// MARK: - Property Protocols

import Foundation

/// An object available as a fully type-erased keypath-value pair.
/// (The keypath-value pairing is fully typesafe internally.)
protocol AnyPropertyProtocol {
    associatedtype Root = Any
    associatedtype Value = Any
    associatedtype KP: AnyKeyPath
    var key: KP { get }
    var value: Value { get }
    var applicator: (Any, Any?, Any?) -> (Any, didChange: Bool) { get set }
}

/// An object available as a partially type-erased keypath-value pair.
/// (The keypath-value pairing is fully typesafe internally.) 
protocol PartialPropertyProtocol: AnyPropertyProtocol
where KP: PartialKeyPath<Root> {
}

/// An object available as a keypath-value pair.
protocol PropertyProtocol: PartialPropertyProtocol
where KP: WritableKeyPath<Root, Value> {
}

// MARK: - Property Initializable

extension AnyPropertyProtocol {
    /// Applies a mutation to a root object.
    func apply(value: Value?, to root: Root) -> (Root, didChange: Bool) {
        return applicator(root, value, nil) as! (Self.Root, didChange: Bool)
    }
}

/// Allows an object to be defined as PropertyInitializable.
/// This allows it to be initialized from a collection of keypath-value pairs (Properties).
protocol PropertyInitializable {
    /// Init from an array of properties.
    init?(_ properties: [PartialProperty<Self>])
    
    /// Create a clone with an array of mutations represented as keypath-value pairs (Properties).
    init(clone: Self, with mutations: [PartialProperty<Self>])
    
    /// A default getter for a "blank" object with its variables all initialized, 
    /// necessary since Swift 5 keypaths may not be used at actual init time to set values.
    /// Note: hopefully some "under the hood" improvements to Swift could
    ///       make this step unneccessary.
    static var _blank: Self { get }
}

/// Implementation of initialization from an array of properties or variadic properties.
extension PropertyInitializable {
    var numberOfNonOptionalProperties: Int {
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

/// Extension to mirror that ensures all children that need to be set at init time, are accounted for.
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

/// A function to check if a property is optional.
func isOptional<T>(_ instance: T) -> Bool {
    guard let displayStyle = Mirror(reflecting: instance).displayStyle 
        else { return false }
    return displayStyle == .optional
}

// MARK: - Implementation

/// An AnyProperty is a fully type-erased, yet internally typesafe, keypath-value pair.
struct AnyProperty: AnyPropertyProtocol {
    typealias KP = AnyKeyPath
    typealias Root = Any
    typealias Value = Any
    
    private(set) var key: KP
    private(set) var value: Value
    var applicator: (Any, Any?, Any?) -> (Any, didChange: Bool)
    
    init<P>(_ base: P) where P: PropertyProtocol {
        self.value = base.value
        self.key = base.key as AnyKeyPath
        self.applicator = base.applicator
    }
}

/// A PartialProperty is a partially type-erased, yet internally typesafe, keypath-value pair.
struct PartialProperty<R>: PartialPropertyProtocol {
    typealias Value = Any
    typealias KP = PartialKeyPath<R>
    typealias Root = R
    
    private(set) var key: PartialKeyPath<R>
    private(set) var value: Value
    var applicator: (Any, Any?, Any?) -> (Any, didChange: Bool)
    
    init<P>(_ base: P) where P: PartialPropertyProtocol, P.Root == R {
        self.value = base.value
        self.key = base.key as PartialKeyPath<Root>
        self.applicator = base.applicator
    }
}

/// A Property is a typesafe keypath-value pair.
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

// MARK: - Tests of PropertyInitializable

struct Test2 {
    var str1: String
    var int4: Int?
    var int5: Int?
}

extension Test2: PropertyInitializable {
    internal static var _blank = Test2(str1: "ERROR-NOT-SET", int4: nil, int5: nil)
}

/// Succeeds to init.
var properties1: [PartialProperty<Test2>] = [
    Property(key: \Test2.str1, value: "asdf").partial,
    //Property(key: \Test2.int4, value: 1337).partial
]

/// Succeeds to init.
var properties2: [PartialProperty<Test2>] = [
    Property(key: \Test2.str1, value: "asdf").partial,
    Property(key: \Test2.int4, value: 1337).partial
]

/// will fail to if commented line is uncommented, because str1 is not optional.
var properties3: [PartialProperty<Test2>] = [
    //Property(key: \Test2.str1, value: "asdf").partial,
    Property(key: \Test2.int4, value: 1337).partial
]

/// Succeeds to init:
var properties4: [PartialProperty<Test2>] = [
    Property(key: \Test2.str1, value: "asdf").partial,
    Property(key: \Test2.int4, value: nil).partial
]

/// Further Tests:

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

// MARK: - Infix Operator

/// Operator <- allows association of a keypath with a value in a typesafe manner 
/// without initializing the root object.
infix operator <-

extension WritableKeyPath {
    static func <- (left: WritableKeyPath<Root, Value>, right: @autoclosure @escaping () throws -> Value) throws -> PartialProperty<Root> {
        return Property<Root, Value>(key: left, value: try right()).partial
    }
}

/// Test for initializing a private(set) value 
/// with force-cast WritableKeyPath
final class Foo {
    private(set) var bar: NSNumber?
    private(set) var baz: URLSession?
}

extension Foo: PropertyInitializable {
    /// Required due to present inability to WritableKeyPath to initialize a value.
    internal static var _blank: Foo = Foo()
}

/// Compiler won't accept this unless the we wrap the cast in parentheses.
var fooProps: [PartialProperty<Foo>] = [
    (\Foo.bar as! WritableKeyPath) <- 5
]

let foo = Foo(fooProps)
assert(foo != nil)

// MARK: - Mockable Properties (Example Implementation)

protocol Mockable: Codable, PropertyInitializable {}

/// Struct defining the configurable and default behavior for MockableProperties.
struct Mock<Value>: PropertyInitializable {
    indirect enum CreationMethod {
        case none
        case single(Value)
        case iterate([Value])
        case randomize([Value])
        case generate(Generator, CreationMethod)
    }
    
    typealias Generator = (CreationMethod) -> Value
    var iteration: Int
    var `default`: Value?
    var creationMethod: CreationMethod
    
    internal static var _blank: Mock<Value> { 
        return Mock<Value>(iteration: 0, default: nil, creationMethod: .none) 
    }
}

/// A property that can generate its own values according to configurable behavior,
/// for the purpose of mocking a service (testing).
protocol MockableProperty: PropertyProtocol where Root: Mockable {
    var mock: Mock<Value> { get }
}

/// Extension that provides the configurable behavior for the `value` of the property.
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
            /// Do nothing. This is just to let us use the default init.
        }
    }
    
    /// Applies the `mock` value to the `root` object of this MockProperty.
    func apply(mock: Mock<Value>, to root: Root) -> (Root, didChange: Bool) {
        return applicator(root, mock, nil) as! (Self.Root, didChange: Bool)
    }
}

// MARK: - Mock Property

/// Example implementation using the above types for service mocking.
/// 
/// MockProperty implements MockableProperty, which allows a Property to 
/// generate its own value at runtime depending upon the value of the creationMethod variable.
struct MockProperty<R: Mockable, V>: MockableProperty {
    typealias Root = R
    typealias Value = V
    typealias KP = WritableKeyPath<R, V>
    
    private(set) var key: KP
    private(set) var mock: Mock<Value>
    
    var applicator: (Any, Any?, Any?) -> (Any, didChange: Bool)
    
    /// Initializing a MockProperty with a single value defaults the creationMethod to .single.
    init(key: KP, value: Value) {
        let mock: Mock<Value> = try! Mock<Value>(
            \.creationMethod <- .single(value)
        )!
        self.init(key: key, mock: mock)
    }
    
    /// Initializing a MockProperty with a range of possibleValues enables the property to be in
    /// .iterate mode, where the getter will iterate to the next value each time, or
    /// .randomize mode, where it will pick randomly from a set of values each time the getter is used.
    init(key: KP, possibleValues: [Value], shouldRandomize: Bool = false, iteration: Int) {
        let mock: Mock<Value> = try! Mock<Value>(
            \.iteration <- iteration,
            \.creationMethod <- (shouldRandomize 
                ? .randomize(possibleValues) 
                : .iterate(possibleValues))
            )!
        self.init(key: key, mock: mock)
    }
    
    /// Initializing a MockProperty with a generator function sets the creationMethod to
    /// .generate, where the function `generator` will be called whenever the getter is invoked,
    /// and it may use the passed-in `creationMethod` to inform its behavior.
    init(key: KP, generator: @escaping Mock<Value>.Generator, creationMethod: Mock<Value>.CreationMethod) {
        let mock: Mock<Value> = try! Mock<Value>(
            \.creationMethod <- .generate(generator, creationMethod)
            )!
        self.init(key: key, mock: mock)
    }
    
    /// Initializing a MockPropety with a predefined Mock behavior object created before-hand.
    /// This function is called by the other initializers.
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
    
    /// Partial type-erasure.
    var partial: PartialProperty<Root> {
        return PartialProperty(self)
    }
    
    /// Full type-erasure.
    var any: AnyProperty {
        return AnyProperty(self)
    }
}

// MARK: Additional Operators 

infix operator +: AdditionPrecedence

/// Convenience extension on Array to support arrays of PartialProperty items.
extension Array where Element == PartialProperty<Any?> {
    /// Infix operator function for partially type-erasing a Property tuple 
    /// and adding it to an array of PartialProperties. This allows the variable type
    /// of each property to be different without violating the static typing of the array.
    static func + <Root, Value>(left: Array<PartialProperty<Root>>, right: (WritableKeyPath<Root, Value>, Value)) -> Array<PartialProperty<Root>> { 
        var new = left
        print(left.count)
        let partial = (Property<Root, Value>(key: right.0, value: right.1)).partial
        new.append(partial)
        print(new.count)
        return new
    }
}

/// A test struct of a mockable object, e.g. from a webservice.
struct Zag: PropertyInitializable {
    var a: Int
    var b: String
    var c: Double?
    
    internal static var _blank: Zag {
        return Zag(a: 1, b: "1", c: 1.0)
    }
} 

/// Here there is a problem where for some reason, the infix operator is not treated correctly by the compiler:

var p: [PartialProperty<Test2>] = [] + (\Test2.str1, "asdf") + (\Test2.int4, 1337) + (\Test2.int5, 999) 

let testy = Test2.init(p)

let z: [PartialProperty<Zag>] = [] + (\.a, 2) + (\.b, "2") + (\.c, 2.0) 

let testz = Zag(z)
assert(testz != nil)
assert(testz!.a == 2)
assert(testz!.b == "2")
assert(testz!.c == 2.0)

// MARK: - Mockables test

/// A test struct of a mockable object, e.g. from a webservice.
struct Mag: Mockable {
    var a: Int
    var b: String
    var c: Double?
    
    internal static var _blank: Mag {
        return Mag(a: 1, b: "10", c: 1.0)
    }
}

typealias GeneratorInput<V> = (initialValue: V?, index: Int?)

/// A generator function for a mock value.
func gen<V: StringProtocol> (_ input: GeneratorInput<V>) throws -> V { 
    let val = "\(input.initialValue ?? "2")"
    let index = input.index ?? 0
    return val + "\(index)" as! V
}

/// Validate that compositional-style PropertyInitializable init works (using an array of properties).
var m: [PartialProperty<Mag>] = try! [
    \.a <- 2,
    \.b <- gen((nil, nil)),
    \.c <- nil
]

/// Validate that PropertyInitializable init works as expected.
let magtest1 = try! Mag(
    \.a <- 2,
    \.b <- gen((nil, nil)),
    \.c <- nil
) 

assert(magtest1 != nil)
assert(magtest1?.a == 2)
assert(magtest1?.b == "20")
assert(magtest1?.c == nil)

/// Extension to support <- operator with Mockable root.
extension WritableKeyPath where Root: Mockable {
    static func <- (left: WritableKeyPath<Root, Value>, right: Mock<Value>) throws -> PartialProperty<Root> {
        return MockProperty<Root, Value>(key: left, mock: right).partial
    }
}

var magtest2 = [Mag]()

/// Example 1 of using PropertyInitializable init with iterable value.
for i in 0...5 {
    magtest2.append((try! Mag(
        \.a <- 2,
        \.b <- Mock(iteration: i, default: nil, creationMethod: .iterate(["a", "b", "c", "d", "e"])),
        \.c <- nil
        ))!
    )
}

let letters = ["a", "b", "c", "d", "e"]

/// Validate that the proper values got set correctly.
for i in 0...4 {
    assert(magtest2[i].b == letters[i])
}

extension Mag {
    // todo
    // Custom property initter
}

/// Further illustrates the current limitations.
struct Hat {
    /// breaks PropertyInitializable if uncommented, 
    /// since let cannot be set via keypaths
    //let a: Int 
    
    /// Breaks PropertyInitializable if uncommented, 
    /// since private var cannot be set via keypaths
    //private var b: Int 
    
    /// Breaks PropertyInitializable if uncommented, 
    /// since let cannot be set via keypaths, 
    /// and there is no way to check if it has a default value
    //let d = 1 
    
    /// Breaks PropertyInitializable if uncommented, 
    /// since private var cannot be set via keypaths, 
    /// and there is no way to check if it has a default value
    //private var e = 1 
    
    /// Breaks PropertyInitializable if uncommented, since f has a default value, 
    /// and private(set) is externally immutable once set. 
    /// Also, now in Swift 5 all keypaths to private(set) are non-writable.
    //private(set) var f = 1 
    
    var c: Int
    
    /// Must be set again for PropertyInitializable init to succeed,
    /// because reflection does not let us see whether a default value gets assigned.
    var g = 1 
    
    var h: Int
}

extension Hat: PropertyInitializable {
    internal static var _blank: Hat {
        return Hat(c: 1, g: 1, h: 1)
    }
}

do {
    let testHat = try Hat(
        /// Breaks if uncommented, as expected since a is let.
        //\.a <- 2, 
        
        /// Breaks if uncommented, as expected since b is private.
        //\.b <- 2, 
        
        /// Breaks if uncommented, as expected since d is let.
        //\.d = 2, 
        
        /// Breaks if uncommented, as expected since e is private.
        //\.e = 2, 
        
        /// Breaks if uncommented, as expected since f has a default value, 
        /// and private(set) is externally immutable once set.
        //\.f = 2, 
        
        \.c <- 2,
        \.g <- 2,
        \.h <- 2
    )
    
    assert(testHat != nil)
} catch {
    print(error)
}

struct Customer: PropertyInitializable {    
    var name: String = ""
    var zipcode: Int = 0
    var addressLine1: String = ""
    var addressLine2: String = ""
    var addressLine3: String = ""
    
    internal static var _blank: Customer {
        get { return Customer() }
    }
}

let dataFromTestWebResponse = [PartialProperty<Customer>]() 
    + (\.name, "Steve Jobs") 
    + (\.zipcode, 97202) 
    + (\.addressLine1, "Reed College")
    + (\.addressLine2, "3203 SE Woodstock Blvd Box #121")

if let customer: Customer = Customer(dataFromTestWebResponse) {
    print(customer)
} else {
    print("Data is missing.")
}

let reedieData = [PartialProperty<Customer>]()
    + (\.zipcode, 97202) 
    + (\.addressLine1, "Reed College")
    + (\.addressLine2, "3203 SE Woodstock Blvd")

let studentBoxAssignments: [(String, Int)] = [("Steve Jobs", 121), ("The Woz", 314)]

var customers = [Customer]()

for (name, box) in studentBoxAssignments {
    let data = reedieData + (\.name, name) + (\.addressLine3, "Box #\(box)")
    if let customer: Customer = Customer(data) {
        customers += [customer]
    } else {
        print("Data is missing.")
    }
}

print(customers)
