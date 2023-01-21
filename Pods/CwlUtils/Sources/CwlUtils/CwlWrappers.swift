//
//  CwlWrappers.swift
//  CwlUtils
//
//  Created by Matt Gallagher on 2015/02/03.
//  Copyright © 2015 Matt Gallagher ( https://www.cocoawithlove.com ). All rights reserved.
//
//  Permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
//  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
//  IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//

import Foundation

/// A class wrapper around a type (usually a value type) so it can be moved without copying.
public class Box<T> {
	public fileprivate(set) var value: T
	public init(_ t: T) {
		value = t
	}
}

//// A class wrapper around a type (usually a value type) so changes to it can be shared (usually as an ad hoc communication channel). NOTE: this version is *not* threadsafe, use AtomicBox for that.
public final class MutableBox<T>: Box<T> {
	public override var value: T { get { return super.value } set { super.value = newValue } }
	public override init(_ t: T) {
		super.init(t)
	}
}

// A class wrapper around a type (usually a value type) so changes to it can be shared in a thread-safe manner (usually as an ad hoc communication channel).
/// "Atomic" in this sense refers to the semantics, not the implementation. This uses a pthread mutex, not CAS-style atomic operations.
public final class AtomicBox<T> {
	private var mutex = PThreadMutex()
	private var internalValue: T
	
	public init(_ t: T) {
		internalValue = t
	}
	
	public var value: T {
		get {
			mutex.unbalancedLock()
			defer { mutex.unbalancedUnlock() }
			return internalValue
		}
	}

	@discardableResult
	public func mutate(_ f: (inout T) throws -> Void) rethrows -> T {
		mutex.unbalancedLock()
		defer { mutex.unbalancedUnlock() }
		try f(&internalValue)
		return internalValue
	}
}

/// A struct wrapper around an optional and a construction function that presents the optional through the `value()` function as though it's a lazy var. Unlike a true lazy var, you can query if the value has been initialized.
public struct Lazy<T> {
	var valueIfInitialized: T?
	let valueConstructor: () -> T
	
	public init(valueConstructor: @escaping () -> T) {
		self.valueConstructor = valueConstructor
	}
	public var isInitialized: Bool { return valueIfInitialized != nil }
	public mutating func value() -> T {
		if let v = valueIfInitialized {
			return v
		}
		let v = valueConstructor()
		valueIfInitialized = v
		return v
	}
}

/// A wrapper around a type (usually a class type) so it can be weakly referenced from an Array or other strong container.
public struct Weak<T: AnyObject> {
	public weak var value: T?
	
	public init(_ value: T?) {
		self.value = value
	}
	
	public func contains(_ other: T) -> Bool {
		if let v = value {
			return v === other
		} else {
			return false
		}
	}
}

/// A wrapper around a type (usually a class type) so it can be referenced unowned from an Array or other strong container.
public struct Unowned<T: AnyObject> {
	public unowned let value: T
	public init(_ value: T) {
		self.value = value
	}
}

/// A enum wrapper around a type (usually a class type) so its ownership can be set at runtime.
public enum PossiblyWeak<T: AnyObject> {
	case strong(T)
	case weak(Weak<T>)
	
	public init(strong value: T) {
		self = PossiblyWeak<T>.strong(value)
	}
	
	public init(weak value: T) {
		self = PossiblyWeak<T>.weak(Weak(value))
	}
	
	public var value: T? {
		switch self {
		case .strong(let t): return t
		case .weak(let weakT): return weakT.value
		}
	}
	
	public func contains(_ other: T) -> Bool {
		switch self {
		case .strong(let t): return t === other
		case .weak(let weakT):
			if let wt = weakT.value {
				return wt === other
			}
			return false
		}
	}
}
