postfix operator …
postfix func … <T, R>(key: T) -> R where T: RawRepresentable, R == T.RawValue {
    return key.rawValue
}

// MARK: - Property Protocols

/// Can represent any property.
///
/// - Type KP: the type-erased KeyPath of the property.
///            Can be downcast.
///
/// - var keypath: AnyKeyPath
///
protocol AnyPropertyProtocol: Any
where KP: AnyKeyPath, Root: Any, Value: Any {
    associatedtype Root
    associatedtype Value
    associatedtype KP
    var key: KP { get }
    var value: Value { get }
}

/// Can represent a property with a specific root.
///
/// - type Root  : the type the property belongs to
/// - type KP    : the partially type-erased KeyPath of the property.
///                Can be downcast.
///
/// - var keypath: PartialKeyPath<Root>
///
protocol PartialPropertyProtocol: AnyPropertyProtocol
where KP: PartialKeyPath<Root> {
    init(key: KP, value: Value)
}
extension PartialPropertyProtocol {
    static func property(key: KP, value: Value) -> Self {
        return Self(key: key, value: value)
    }
}

/// Can represent a property with a specific root.
///
/// - type Root  : the type the property belongs to
/// - type KP    : the KeyPath of the property.
/// - type Value : the type of the property's value
///
/// - var keypath: KeyPath<Root, Value>
///
protocol PropertyProtocol: PartialPropertyProtocol
where KP: KeyPath<Root, Value> {
    init(key: KP, value: Value)
}
extension PropertyProtocol {
    static func property(key: KP, value: Value) -> Self {
        return Self(key: key, value: value)
    }
}

/// Can represent a property with a specific root.
///
/// - type Root  : the type the property belongs to
/// - type KP    : the WritableKeyPath of the property.
/// - type Value : the type of the property's value
///
/// - var keypath: WritableKeyPath<Root, Value>
///
protocol WritablePropertyProtocol: PropertyProtocol
where KP: WritableKeyPath<Root, Value> {}

/// Can represent a property with a specific root.
///
/// - type Root  : the type the property belongs to
/// - type KP    : the partially ReferenceWritableKeyPath of the property.
/// - type Value : the type of the property's value
///
/// - var keypath: ReferenceWritableKeyPath<Root, Value>
///
protocol ReferenceWritablePropertyProtocol: PropertyProtocol
where KP: ReferenceWritableKeyPath<Root, Value> {}

// MARK: - Array Extension

extension Array
where Element: AnyPropertyProtocol {
    ///
    func firstValue<R, V>(for keyPath: KeyPath<R,V>) -> V? where Element.Root == R {
        guard let value: V = (self.first { prop in prop.key == keyPath })?.value as? V else {
            return nil
        }
        return value
    }
}

/// Proof of concept
struct Foo {
    let bar: String
    let baz: Int
    init?<P>(properties: [P]) where P: AnyPropertyProtocol, P.Root == Foo {
        guard 
            let bar = properties.firstValue(for: \Foo.bar),
            let baz = properties.firstValue(for: \Foo.baz)
            else {
                return nil
        }
        self.bar = bar
        self.baz = baz
    }
}

struct Bar {
    var keys: [AnyKeyPath] = [\Bar.foo, \Bar.baz]
    let types = ["", 0] as [Any]
    var foo: String = ""
    var baz: Int = 0
    //func asdf<KP, P: AnyPropertyProtocol>(kp: KP, p: P) where KP: KeyPath<
    init?<P>(properties: [P]) where P: PartialPropertyProtocol, P.Root == Bar {
        print(keys)
        for key in keys {
            guard let prop = (properties.first { $0.key == key && type(of: $0.key) == type(of: key) })
                else {
                    print("fail")
                    continue
            }
            print(prop.key)
            let nk = prop.key
            let r = type(of: nk).rootType 
            let v = type(of: nk).valueType
            print(v)
            let k = types.first { type(of: $0) == v }
            func s<H>(_ g:H) {
                print(H.self)
            }
            s(k!)
            print(nk)
            //self[keyPath:nk] = prop.value 
            func encode<F>(_ value: F, forKey: WritableKeyPath<Bar,F>) {
                
            }
        }
        return nil
    }
}

let kpTypes = [KeyPath<Bar,String>.self, KeyPath<Bar,Int>.self]
let kps = [\Bar.foo, \Bar.baz]
let types = [String.self, Int.self] as [Any]

var debug = ""

func typify<PKP, R, V>(_ pkp: PKP) -> V? where PKP: PartialKeyPath<R> {
    guard let kp = pkp as? KeyPath<R,V> else {
        return nil
    }
    if "" is V {
        print("\(V.self) is string")
    }
    else if 0 is V {
        print("\(V.self) is int")
    }
    else {
        print("\(V.self)")
    }
    return nil
}

for x in kpTypes {
    debug += "\(type(of: x))\n"
}

for x in kps {
    debug += "\(type(of: x))\n"
    if let str: String = typify(x) {
        
    } else if let int: Int = typify(x) {
        
    }
}

print(debug)

struct PartialProperty<R>: PartialPropertyProtocol {
    typealias Root = R
    typealias KP = PartialKeyPath<R>
    typealias Value = Any
    let key: KP
    let value: Value
    init(key: KP, value: Value) {
        self.key = key
        self.value = value
    }
}

///
struct Property<R, V>: PropertyProtocol {
    typealias Root = R
    typealias Value = V
    typealias KP = KeyPath<R,V>
    let key: KP
    let value: V
}

let props = [PartialProperty(key: \Bar.foo, value: "foo"), PartialProperty(key: \Bar.baz, value: 1337)]

let bar = Bar(properties: props)


// MARK: - Other array extension funcs 

extension Array
    where Element: AnyPropertyProtocol 
{
    /// 
    func properties<R, V, A>() -> [A]
        where
        Element: AnyPropertyProtocol,
        A: PropertyProtocol,
        A.Root == R, A.Value == V
    {
        var propertyArray = [A]()
        for element in self {
            propertyArray.append(A.property(
                key: element.key as! A.KP,
                value: element.value as! V
            ))
        }
        return propertyArray
    }
    
    ///
    func partialProperties<R, A>() -> [A]
        where Element.Root == R,
        A: PartialPropertyProtocol,
        A.Root == R, A.Value == Any
    {
        var propertyArray = [A]()
        for element in self {
            propertyArray.append(A.property(
                key: element.key as! A.KP, value: element.value
            ))
        }
        return propertyArray
    }
}

// MARK: - Initializability Protocols

///
///
///
protocol InitializableWithProperties {}
//    associatedtype PSI: PropertiesSufficientForInitializationProtocol where PSI.Root == Self
//    static var propertiesSufficientForInitialization: PSI { get }
//    init?<PSI>(_ properties: PSI)
//extension InitializableWithProperties {
//    init?<AnyProperty>(_ properties: [AnyProperty])
//    where AnyProperty: AnyPropertyProtocol {
//        for property in properties {
//            self[keyPath: property.key] = property.value
//        }
//        return nil
//    }
//}
//class AnyProperty: AnyPropertyProtocol {
//
//}
//
//
//infix operator √
//prefix func √<R: AnyKeyPath>(left: R, right: Any) -> AnyProperty {
//    return root
//}
//
//let x = √\Foo.bar
//print(x)
//typealias Properties<T> = [PartialPropertyProtocol] where T == PartialPropertyProtocol.Root
/// A container for a set of properties that are sufficient to initialize the Root type.
///
/// - type Root  : the type the property belongs to
///
//protocol PropertiesSufficientForInitializationProtocol {
//    associatedtype Root
//    associatedtype PP = PartialPropertyProtocol where PP.Root == Root
//    var sufficientForInitialization: [PP] { get }
//}
//
//struct Properties<R, P: PartialPropertyProtocol>: PropertiesSufficientForInitializationProtocol {
//    typealias Root = R
//    var sufficientForInitialization: [P]
//}
//struct ProofOfConcept: InitializableWithProperties {
//    typealias PSI = Properties
//    static var propertiesSufficientForInitialization: PSI = Properties()
//    let foo: String
//    let bar: Int
//    init?(_ properties: PSI) throws {
//        for property in properties.sufficientForInitialization {
//
//        }
//    }
//}
/// Allows you to access the rawValue by appending * to the case.
/// e.g.: .CaseName* == .CaseName.rawValue
/// This allows cleaning up the call site and reducing boilerplate :D
