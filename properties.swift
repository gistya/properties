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
where KP: WritableKeyPath<Root, Value> {
    
}

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
    init()
    init?(with properties: [PartialProperty<Self>], copying rest: Self?)
}
extension PropertyInitializable {
    init?(with properties: [PartialProperty<Self>], copying rest: Self?) {
        var proto: Self 
        var i = 0
        
        switch rest {
        case nil:
            proto = Self()
        case let copy:
            proto = copy!
            i = Int.max
        }
        
        for property in properties {
            let (result, didChange) = property.apply(value: property.value, to: proto)
            if didChange {
                proto = result
                i != Int.max && property.value...?! ? i += 1 : ()
            }
        }
        
        if i >= proto.numberOfRequiredProperties {
            self = proto
            return
        } else {
            return nil
        }
    }
    
    var numberOfRequiredProperties: Int {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            print(child)
        }
        print(mirror.displayStyle)
        let count = (mirror.children.filter { child in
            guard let varName = child.label, 
                let descendant = mirror.descendant(varName) else {
                    print("no descendant")
                    return false
            }
            print("descendant: ",descendant)
            if descendant == nil {
                print("nil descendant")
                return false
            }
            return descendant...?!
        }).count
        print("count: ",count)
        return count
    }
}

struct Test2: PropertyInitializable {
    private(set) var str1: String = ""
    private(set) var int4: Int? = nil
    init() {}
}

postfix operator ...?!
postfix func ...?!<T>(_ instance: T) -> Bool {
    let subject = "\(Mirror(reflecting: instance).subjectType)"
    return !subject.hasPrefix("Optional") 
}
// hacky; is there a better way?

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

let test1 = Test2(with: properties1, copying: nil)
assert(test1 != nil, "test1 should not be nil")

let test2 = Test2(with: properties2, copying: nil)
assert(test2 != nil, "test2 should not be nil")

let test3 = Test2(with: properties3, copying: nil)
assert(test3 == nil, "test2 should be nil")

let test4 = Test2(with: properties4, copying: test2)
assert(test4 != nil, "test4 should not be nil")
assert(test4?.int4 == nil, "test4.int4 should be nil")

let test5 = Test2(with: properties3, copying: test2)
assert(test5 != nil, "test5 should not be nil")
assert(test5?.int4 == 1337, "test5.int5 should be 1337")

final class Foo: PropertyInitializable {
    private(set) var bar: NSNumber = 0
    private(set) var baz: URLSession? = nil
    required init() {}
}

var fooProps: [PartialProperty<Foo>] = [
    Property(key: \Foo.bar, value: 5).partial
]

let foo = Foo(with: fooProps, copying: nil)


