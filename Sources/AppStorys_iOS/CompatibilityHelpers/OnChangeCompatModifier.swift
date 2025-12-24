//
//  OnChangeCompatModifier.swift
//  AppStorys_iOS
//
//  Created by Ansh Kalra on 23/12/25.
//


import SwiftUI

// MARK: - iOS 14+ Compatible onChange Wrapper
struct OnChangeCompatModifier<Value: Equatable>: ViewModifier {

    let value: Value
    let perform: (_ oldValue: Value, _ newValue: Value) -> Void

    @State private var previousValue: Value

    init(value: Value, perform: @escaping (_ oldValue: Value, _ newValue: Value) -> Void) {
        self.value = value
        self.perform = perform
        _previousValue = State(initialValue: value)
    }

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: value, initial: false) { oldValue, newValue in
                perform(oldValue, newValue)
            }
        } else {
            content.onChange(of: value) { newValue in
                let oldValue = previousValue
                previousValue = newValue
                perform(oldValue, newValue)
            }
        }
    }
}

// MARK: - View Extension
extension View {
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(
        of value: Value,
        perform: @escaping (_ oldValue: Value, _ newValue: Value) -> Void
    ) -> some View {
        self.modifier(OnChangeCompatModifier(value: value, perform: perform))
    }
}
