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
    ///
    init()
    init?(with properties: [PartialProperty<Self>], copying rest: Self?)
}
extension PropertyInitializable {
    init?(with properties: [PartialProperty<Self>], copying rest: Self?) {
        var proto: Self = rest ?? Self()
        let mirror = Mirror(reflecting: proto)
        var i = 0
        
        for property in properties {
            let (result, didChange) = property.apply(value: property.value, to: proto)
            if didChange {
                proto = result
                i += 1
            }
        }
        
        if i == Self.numberOfRequiredProperties(on: proto) {
            self = proto
            return
        } else {
            return nil
        }
    }
    static func numberOfRequiredProperties(on instance: Self) -> Int {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            print(child)
        }
        print(mirror.displayStyle)
        return (mirror.children.filter { child in
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
            let subject = "\(Mirror(reflecting: descendant).subjectType)"
            return subject.hasPrefix("Optional")
        }).count
    }
}


protocol KeyPathsForInitProtocol {
    associatedtype Root
    typealias PKP = PartialKeyPath<Root>
    static var required: [PKP] { get }
    //static var optional: [PKP] { get }
}

struct Test2 {
    private(set) var str1: String
    //private(set) var int4: Int?
    
    /// Necessary machinery for property array init
    private struct KeyPathsForInit: KeyPathsForInitProtocol {
        typealias Root = Test2
        static let required: [PartialKeyPath<Test2>] = [\Test2.str1]
        //static let optional: [PartialKeyPath<Test2>] = [\Test2.int4]
    }
    
    init(str1: String = "notSet"/*, int4: Int? = -999*/) {
        self.str1 = str1
        //self.int4 = int4
    }
    
    init?(with properties: [PartialProperty<Test2>], copying rest: Test2? = nil) {
        var proto: Test2 = rest ?? Test2()
        var i = 0
        
        for property in properties {
            let (result, didChange) = property.apply(value: property.value, to: proto)
            if didChange {
                proto = result
                i += 1
            }
        }
        
        if i == KeyPathsForInit.required.count {
            self = proto
            return
        } else {
            return nil
        }
    }
}

var properties3: [PartialProperty<Test2>] = [
    Property(key: \Test2.str1, value: "asdf").partial,
    //Property.partial(key: \Test2.int4, value: 1337)
]

let x = Test2.init()
let z = x[keyPath: \Test2.str1]

let test_2 = Test2(with: properties3)


