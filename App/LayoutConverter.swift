//
//  LayoutConverter.swift
//  Flipio
//
//  Converts text between keyboard layouts.
//

import Foundation

/// Converts text between two keyboard layouts.
struct LayoutConverter: Sendable {
    private let layoutProvider: LayoutProvider

    init(layoutProvider: LayoutProvider = .init()) {
        self.layoutProvider = layoutProvider
    }

    /// Converts text to the other layout (e.g. "htgf" → "репа", "репа" → "htgf").
    /// Uses preferred pair of layouts (matched with OS preferred languages).
    /// Returns unchanged text if no keyboard layouts are available.
    func convert(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }
        
        guard let selection = layoutProvider.preferredSelection() else {
            return text
        }
        return selection.pair.convertMixed(text)
    }

    /// Converts text and returns detailed conversion result including target layout.
    /// Uses preferred pair of layouts (matched with OS preferred languages).
    /// Returns unchanged text if no keyboard layouts are available.
    func convertWithTarget(_ text: String) -> ConversionResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let selection = layoutProvider.preferredSelection() else {
            return nil
        }
        
        let conversion = selection.pair.convertMixedWithTarget(text)
        return ConversionResult(
            text: conversion.text,
            targetLayout: conversion.targetLayout,
            selection: selection
        )
    }
    
    /// Converts text to the next layout in the cycle (for live typing).
    /// Cycles through all available layouts: A->B->C->A...
    /// Returns the conversion result with the target layout ID.
    func convertToNextLayout(_ text: String) -> NextLayoutConversionResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        guard let nextLayout = layoutProvider.nextLayoutInfo() else {
            return nil
        }
        
        // Build conversion mapping from current layout to next layout
        guard let currentLayout = getCurrentLayoutInfo() else {
            return nil
        }
        
        let mapping = KeyboardLayoutPairBuilder.buildOneWayMapping(
            from: currentLayout.source,
            to: nextLayout.source
        )
        
        // Convert text using the mapping
        let convertedText = convertUsingMapping(text, mapping: mapping)
        
        return NextLayoutConversionResult(
            text: convertedText,
            targetLayoutID: nextLayout.id
        )
    }
    
    /// Gets information about the current keyboard layout.
    private func getCurrentLayoutInfo() -> KeyboardInputSourceInfo? {
        let provider = SystemInputSourceProvider()
        let sources = provider.selectableSources()
        guard let currentID = provider.currentSourceID() else {
            return sources.first
        }
        return sources.first { $0.id == currentID }
    }
    
    /// Converts text using a character mapping.
    private func convertUsingMapping(_ text: String, mapping: [Character: Character]) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        
        for char in text {
            if let mapped = mapping[char] {
                result.append(mapped)
            } else if let lower = char.lowercased().first, let mapped = mapping[lower] {
                result.append(Character(mapped.uppercased()))
            } else {
                result.append(char)
            }
        }
        return result
    }

    /// Switches the system input source to the target layout from the conversion result.
    func applyTargetLayout(_ result: ConversionResult?) {
        guard let result else { return }
        layoutProvider.activateLayout(result.targetLayout, selection: result.selection)
    }
    
    /// Switches to the next layout by ID.
    func applyNextLayout(_ result: NextLayoutConversionResult?) {
        guard let result else { return }
        layoutProvider.activateLayoutByID(result.targetLayoutID)
    }
}

/// Provides keyboard layout selections and manages input source activation.
struct LayoutProvider: Sendable {
    private let inputSourceProvider = SystemInputSourceProvider()
    
    /// Returns the preferred keyboard layout selection from system input sources.
    /// Uses layouts matched to OS preferred languages.
    /// Returns nil if fewer than 2 input sources are available.
    func preferredSelection() -> KeyboardLayoutSelection? {
        guard let pair = inputSourceProvider.selectPreferredPair() else {
            return nil
        }
        return KeyboardLayoutPairBuilder.buildSelection(from: pair.primary, and: pair.secondary)
    }
    
    /// Returns the next layout in the cycle for live typing.
    /// Cycles through all available layouts: A->B->C->A...
    func nextLayoutInfo() -> KeyboardInputSourceInfo? {
        let currentID = inputSourceProvider.currentSourceID()
        return inputSourceProvider.selectNextLayout(after: currentID)
    }

    /// Activates the specified layout side as the system input source.
    func activateLayout(_ target: KeyboardLayoutSide?, selection: KeyboardLayoutSelection) {
        guard let target else { return }
        
        let sourceID: String?
        switch target {
        case .layoutA:
            sourceID = selection.sourceAID
        case .layoutB:
            sourceID = selection.sourceBID
        }
        
        guard let sourceID else { return }
        inputSourceProvider.activateInputSource(id: sourceID)
    }
    
    /// Activates the layout by its source ID.
    func activateLayoutByID(_ sourceID: String) {
        inputSourceProvider.activateInputSource(id: sourceID)
    }
}
