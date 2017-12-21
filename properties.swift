
// MARK: - Property Protocols

import Foundation

/// Can represent any property.
///
/// - Type KP: the type-erased KeyPath of the property.
///            Can be downcast.
///
/// - var keypath: AnyKeyPath
///
protocol AnyPropertyProtocol {
    associatedtype Root = Any
    associatedtype Value = Any?
    associatedtype KP: AnyKeyPath
    var key: KP { get }
    var value: Value { get }
}

/// Can represent a property with a specific root.
///
/// - type Root  : the type the property belongs to
/// - type KP    : the partially type-erased KeyPath of the property.
///                Can be downcast.
///
/// - var keypath: PartialKeyPath<Root>
///
protocol PartialPropertyProtocol: AnyPropertyProtocol
where KP: PartialKeyPath<Root> {
    
}

protocol PropertyProtocol: PartialPropertyProtocol
where KP: KeyPath<Root, Value> {
    init(key: KP, value: Value)
}

struct Property<R, V>: PropertyProtocol {
    typealias Root = R
    typealias Value = V
    typealias KP = KeyPath<R, V>
    let key: KP
    let value: Value
    init(key: KP, value: Value) {
        self.key = key
        self.value = value
    }
    
    init(_ arg: (key: KP, value: Value)) {
        self.key = arg.key
        self.value = arg.value
    }
    
    public static func partial(
        key: KP,
        value: Value) -> PartialProperty<Root>
    {
        let property = self.init(
            key: key,
            value: value
        )
        return PartialProperty(property)
    }
}

internal protocol _AnyPropertyBox {
    var key: AnyKeyPath { get }
    var value: Any? { get }
    var _base: Any { get }
}

internal protocol _PartialPropertyBox: _AnyPropertyBox {
    associatedtype _Root
}

internal struct _ConcretePartialPropertyBox<Base: PropertyProtocol> {
    typealias _Root = Base.Root
    typealias _Value = Base.Value
    internal var _baseProperty: Base
}

extension _ConcretePartialPropertyBox: _PartialPropertyBox {
    internal var _base: Any { return _baseProperty }
    
    var key: AnyKeyPath {
        return _baseProperty.key
    }
    
    internal var value: Any? {
        get {
            return _baseProperty.value as Any?
        }
    }
    
    internal init(_ base: Base) {
        self._baseProperty = base
    }
}

 struct PartialProperty<R>: PartialPropertyProtocol {
    typealias Value = Any?
    typealias KP = PartialKeyPath<R>
    typealias Root = R
    
    var key: PartialKeyPath<R>
    var value: Value
    
    internal var _box: _AnyPropertyBox

    init<V>(_ base: Property<Root, V>) {
        self.value = base.value
        self.key = base.key as! PartialKeyPath<Root>
        self._box = _ConcretePartialPropertyBox<Property<Root, V>>(base)
    }
    public var unBoxed: Any { return _box._base }
}


typealias Properties<R> = Array<PartialProperty<R>>

extension Array
where Element: AnyPropertyProtocol {
    ///
    func firstValue<R, V>(for key: KeyPath<R,V>, default rest: R?) -> V?
        where Element.Root == R {
            return first { $0.key == key }?.value as? V ?? rest?[keyPath: key]
    }
    
    ///
    func firstOptionalValue<R, V>(for key: KeyPath<R,Optional<V>>, default rest: R?) -> V?
        where Element.Root == R {
            return first { $0.key == key }?.value as? V ?? rest?[keyPath: key]
    }
}

protocol PropertyInitializable {
    ///
    init?(with properties: [PartialProperty<Self>], copying rest: Self?)
}

extension Optional where Wrapped: PropertyInitializable {
    ///
    static func ||<Value>(
        lhs: ([PartialProperty<Wrapped>], KeyPath<Wrapped, Value>),
        rhs: Wrapped?)
        -> Value?
    {
        return lhs.0.firstValue(for: lhs.1, default: rhs)
    }
    
    ///
    static func ||<Value>(
        lhs: ([PartialProperty<Wrapped>], KeyPath<Wrapped, Value?>),
        rhs: Wrapped?)
        -> Value?
    {
        return lhs.0.firstValue(for: lhs.1, default: rhs)!
    }
}

struct Test: PropertyInitializable {
    let str1: String
    let str2: String
    let str3: String?
    let str4: String?
    let int1: Int
    let int2: Int
    let int3: Int?
    let int4: Int?
    
    init?(with properties: [PartialProperty<Test>], copying rest: Test?) {
        // Init non-optional properties using a guard statement.
        guard let str1 = (properties, \.str1) || rest,
            let str2 = (properties, \.str2) || rest,
            let int1 = (properties, \.int1) || rest,
            let int2 = (properties, \.int2) || rest
            else { return nil }
        self.str1 = str1
        self.str2 = str2
        self.int1 = int1
        self.int2 = int2
        
        // Optional properties can simply be assigned.
        self.str3 = (properties, \.str3) || rest
        self.str4 = (properties, \.str4) || rest
        self.int3 = (properties, \.int3) || rest
        self.int4 = (properties, \.int4) || rest
    }
}

var properties1: Properties<Test> = [
    Property.partial(key: \Test.str1, value: "1"),
    Property.partial(key: \Test.str2, value: "2"),
    Property.partial(key: \Test.str3, value: "3"),
    Property.partial(key: \Test.str4, value: nil),
    Property.partial(key: \Test.int1, value: 1),
    Property.partial(key: \Test.int2, value: 2),
    Property.partial(key: \Test.int3, value: 3),
    Property.partial(key: \Test.int4, value: nil)
]

var properties2: [PartialProperty<Test>] = [
    Property.partial(key: \Test.str1, value: "foo"),
    Property.partial(key: \Test.str3, value: "bar"),
    Property.partial(key: \Test.str4, value: "baz"),
    Property.partial(key: \Test.int3, value: 1300),
    Property.partial(key: \Test.int4, value: 37)
]

let test1 = Test(with: properties1, copying: nil)

assert(test1 != nil, "test1 should not be nil.")

let test2 = Test(with: properties2, copying: test1)

assert(test2 != nil, "test2 should not be nil.")
assert(test2!.int3! + test2!.int4! == 1337, "test2 should be l33t.")

print(test2!.int3! + test2!.int4!)

let test3 = Test(with: properties2, copying: nil)

assert(test3 == nil, "test3 should be nil.")
