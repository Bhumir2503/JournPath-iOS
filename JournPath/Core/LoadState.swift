enum LoadState<Value> {
    case idle, loading
    case loaded(Value)
    case failed(AnyAppError)

    var value: Value? {
        if case .loaded(let v) = self { return v }
        return nil
    }
    var error: AnyAppError? {
        if case .failed(let e) = self { return e }
        return nil
    }
}
