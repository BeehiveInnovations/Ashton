import Foundation


/// Dictionary based cache, used for FontStyles and StyleAttributes during reading of HTML.
public final class Cache<Key: Hashable, Value> {

    private var elements: [Key: Value]
    private let queue = DispatchQueue(label: "com.ashton.cache-queue", attributes: .concurrent)

    // MARK: - Properties

    var isEmpty: Bool { 
        var result = false
        queue.sync {
            result = self.elements.isEmpty
        }
        return result
    }

    // MARK: - Lifecycle

    init(_ elements: [Key: Value] = [:]) {
        self.elements = elements
    }

    // MARK: - Cache

    subscript(key: Key) -> Value? {
        get {
            var value: Value?
            queue.sync {
                value = self.elements[key]
            }
            return value
        }
        set {
            queue.sync(flags: .barrier) {
                self.elements[key] = newValue
            }
        }
    }
    
    func clear() {
        queue.sync(flags: .barrier) {
            self.elements.removeAll()
        }
    }
}
