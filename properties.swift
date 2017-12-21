// working

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
    associatedtype Value = Any
    associatedtype KP: AnyKeyPath
    var key: KP { get set }
    var value: Value { get set }
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
    var applicator: (Root, Any?) -> (Root, didChange: Bool) { get set }
}

extension PartialPropertyProtocol {
    func apply(value: Any?, to: Root) -> (Root, didChange: Bool) {
        return applicator(to, value)
    }
}

protocol PropertyProtocol: PartialPropertyProtocol
where KP: WritableKeyPath<Root, Value> {}

// MARK: - Implementations

struct PartialProperty<R>: PartialPropertyProtocol {
    typealias Value = Any
    typealias KP = PartialKeyPath<R>
    typealias Root = R
    
    var key: PartialKeyPath<R>
    var value: Value
    var applicator: (Root, Any?) -> (Root, didChange: Bool)
    
    init<V>(_ base: Property<Root, V>) {
        self.value = base.value
        self.key = base.key as! PartialKeyPath<Root>
        self.applicator = base.applicator
    }
}


struct Property<R, V>: PropertyProtocol {
    typealias Root = R
    typealias Value = V
    typealias KP = WritableKeyPath<R, V>
    
    var key: KP
    var value: Value
    var applicator: (Root, Any?) -> (Root, didChange: Bool)
    
    init(key: KP, value: Value) {
        self.key = key
        self.value = value
        self.applicator = {
            var instance: Root = $0
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
            let (updated, didChange) = property.apply(value: property.value, to: new)
            if didChange {
                new = updated
                if !isOptional(property.value) { propertiesLeftToInit -= 1 }
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
