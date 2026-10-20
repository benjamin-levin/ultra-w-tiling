/*
    SPDX-FileCopyrightText: 2026 Powerhouse
    SPDX-License-Identifier: GPL-2.0-or-later

    Ultrawide Zones
    KWin script for shortcut-driven horizontal segment layouts.
*/

var zoneCount = 3;
var zonesByWindow = {};
var moveStates = {};
var shiftArmedUntil = 0;
var spanArmedUntil = 0;
var DRAG_ARM_MS = 750;

function activeWindow() {
    return workspace.activeWindow || workspace.activeClient;
}

function windowKey(window) {
    if (!window) {
        return "";
    }
    if (window.internalId !== undefined) {
        return String(window.internalId);
    }
    if (window.windowId !== undefined) {
        return String(window.windowId);
    }
    return String(window.caption);
}

function usableArea(window) {
    return workspace.clientArea(KWin.MaximizeArea, window);
}

function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}

function isValidMode(count) {
    return count >= 3 && count <= 8;
}

function remember(window, start, span) {
    zonesByWindow[windowKey(window)] = {
        count: zoneCount,
        start: start,
        span: span
    };
}

function cursorPoint() {
    return {
        x: workspace.cursorPos.x,
        y: workspace.cursorPos.y
    };
}

function remembered(window) {
    var state = zonesByWindow[windowKey(window)];
    if (!state || state.count !== zoneCount) {
        return null;
    }
    return state;
}

function frameFor(area, start, span) {
    var frame = area;
    var left = Math.round(area.x + area.width * start / zoneCount);
    var right = Math.round(area.x + area.width * (start + span) / zoneCount);
    frame.x = left;
    frame.y = area.y;
    frame.width = right - left;
    frame.height = area.height;
    return frame;
}

function frameForWindow(window, start, span) {
    return frameFor(usableArea(window), start, span);
}

function outputAreaForPoint(window, point) {
    var output = workspace.screenAt(point);
    if (!output && window && window.output) {
        output = window.output;
    }
    if (!output) {
        return usableArea(window);
    }

    return workspace.clientArea(KWin.MaximizeArea, output, workspace.currentDesktop);
}

function rect(x, y, width, height) {
    return {
        x: x,
        y: y,
        width: width,
        height: height
    };
}

function applyZoneToWindow(window, start, span) {
    if (!window || window.specialWindow || window.fullScreen) {
        return;
    }

    start = clamp(start, 0, zoneCount - 1);
    span = clamp(span, 1, zoneCount - start);

    window.setMaximize(false, false);
    detachFromTile(window);
    window.frameGeometry = frameForWindow(window, start, span);
    remember(window, start, span);
}

function applyZone(start, span) {
    applyZoneToWindow(activeWindow(), start, span);
}

function shouldPreserve(window) {
    return window && !window.specialWindow && !window.fullScreen;
}

function copyFrameGeometry(window) {
    var source = window.frameGeometry;
    var copy = workspace.clientArea(KWin.MaximizeArea, window);
    copy.x = source.x;
    copy.y = source.y;
    copy.width = source.width;
    copy.height = source.height;
    return copy;
}

function detachFromTile(window) {
    if (!window || window.tile === undefined) {
        return;
    }

    try {
        window.tile = null;
    } catch (error) {
        print("Ultrawide Zones: could not detach active window from tile: " + error);
    }
}

function tiledWindows() {
    var result = [];
    var seen = {};
    var windows = workspace.windowList ? workspace.windowList() : workspace.stackingOrder;

    for (var i = 0; i < windows.length; i++) {
        var window = windows[i];
        if (!shouldPreserve(window) || window.tile === undefined || !window.tile) {
            continue;
        }

        var key = windowKey(window);
        if (seen[key]) {
            continue;
        }

        seen[key] = true;
        result.push({
            window: window,
            geometry: copyFrameGeometry(window)
        });
    }

    return result;
}

function detachWindows(savedWindows) {
    for (var i = 0; i < savedWindows.length; i++) {
        detachFromTile(savedWindows[i].window);
    }
}

function restoreWindows(savedWindows) {
    for (var i = 0; i < savedWindows.length; i++) {
        restoreGeometry(savedWindows[i].window, savedWindows[i].geometry);
    }
}

function setLiveMode(count) {
    var savedWindows = tiledWindows();

    detachWindows(savedWindows);
    zoneCount = count;
    zonesByWindow = {};
    rebuildLiveTiles(count);
    restoreWindows(savedWindows);
}

function clearRootTile(root) {
    var guard = 0;
    while (root.tiles.length > 0 && guard < 20) {
        root.tiles[root.tiles.length - 1].remove();
        guard++;
    }
}

function normalizeRootTile(root, count) {
    var width = 1 / count;

    for (var i = 0; i < root.tiles.length; i++) {
        root.tiles[i].relativeGeometry = rect(i * width, 0, width, 1);
    }
}

function rebuildRootTile(root, count) {
    clearRootTile(root);
    root.padding = 0;
    root.layoutDirection = 1;
    root.split(1);

    if (count >= 3) {
        root.tiles[0].split(1);
    }

    if (count >= 4) {
        root.tiles[root.tiles.length - 1].split(1);
    }

    if (count === 5) {
        root.tiles[0].relativeGeometry = rect(0, 0, 0.2, 1);
        root.tiles[1].relativeGeometry = rect(0.2, 0, 0.2, 1);
        root.tiles[2].relativeGeometry = rect(0.4, 0, 0.2, 1);
        root.tiles[3].relativeGeometry = rect(0.6, 0, 0.4, 1);
        root.tiles[3].split(1);
    }

    if (count >= 6) {
        root.tiles[0].relativeGeometry = rect(0, 0, 1 / 6, 1);
        root.tiles[1].relativeGeometry = rect(1 / 6, 0, 1 / 6, 1);
        root.tiles[2].relativeGeometry = rect(2 / 6, 0, 2 / 6, 1);
        root.tiles[3].relativeGeometry = rect(4 / 6, 0, 2 / 6, 1);
        root.tiles[3].split(1);
        root.tiles[2].split(1);
    }

    normalizeRootTile(root, count);
}

function rebuildLiveTiles(count) {
    for (var i = 0; i < workspace.screens.length; i++) {
        var manager = workspace.tilingForScreen(workspace.screens[i]);
        if (!manager || !manager.rootTile) {
            continue;
        }

        rebuildRootTile(manager.rootTile, count);
    }
}

function restoreGeometry(window, geometry) {
    if (!window || !geometry) {
        return;
    }

    try {
        window.frameGeometry = geometry;
    } catch (error) {
        print("Ultrawide Zones: could not restore active window geometry: " + error);
    }
}

function zoneForPoint(area, point) {
    var relativeX = clamp(point.x - area.x, 0, area.width - 1);
    return clamp(Math.floor(relativeX / (area.width / zoneCount)), 0, zoneCount - 1);
}

function isShiftArmed() {
    return Date.now() <= shiftArmedUntil;
}

function isSpanArmed() {
    return Date.now() <= spanArmedUntil;
}

function selectionForMove(window, state) {
    var area = outputAreaForPoint(window, state.last);
    var end = zoneForPoint(area, state.last);
    var start = state.span ? zoneForPoint(area, state.start) : end;
    var first = Math.min(start, end);
    var last = Math.max(start, end);
    var span = last - first + 1;

    return {
        area: area,
        start: first,
        span: span,
        frame: frameFor(area, first, span)
    };
}

function showSelectionOutline(window, state) {
    // KWin already draws a native outline whenever physical Alt is held
    // during a move. Drawing a second outline here causes competing previews.
    return;
}

function armShiftDrag() {
    shiftArmedUntil = Date.now() + DRAG_ARM_MS;

    for (var key in moveStates) {
        if (moveStates.hasOwnProperty(key)) {
            moveStates[key].shift = true;
            moveStates[key].last = cursorPoint();
            showSelectionOutline(moveStates[key].window, moveStates[key]);
        }
    }
}

function armSpanDrag() {
    shiftArmedUntil = Date.now() + DRAG_ARM_MS;
    spanArmedUntil = Date.now() + DRAG_ARM_MS;
    print("Ultrawide Zones: span drag armed");

    for (var key in moveStates) {
        if (moveStates.hasOwnProperty(key)) {
            moveStates[key].shift = true;
            if (!moveStates[key].span) {
                moveStates[key].span = true;
                moveStates[key].start = cursorPoint();
            }
            moveStates[key].last = cursorPoint();
            showSelectionOutline(moveStates[key].window, moveStates[key]);
        }
    }
}

function releaseDrag() {
    shiftArmedUntil = 0;
    spanArmedUntil = 0;

    if (Object.keys(moveStates).length === 0) {
        workspace.hideOutline();
    }
}

function maybeArmMoveState(state) {
    if (!state.shift && isShiftArmed()) {
        state.shift = true;
        state.start = cursorPoint();
        state.last = state.start;
    }

    if (!state.span && isSpanArmed()) {
        state.shift = true;
        state.span = true;
        state.start = cursorPoint();
        state.last = state.start;
    }
}

function beginMove(window) {
    if (!shouldPreserve(window)) {
        return;
    }

    var key = windowKey(window);
    var point = cursorPoint();
    moveStates[key] = {
        window: window,
        start: point,
        last: point,
        shift: isShiftArmed(),
        span: isSpanArmed()
    };
}

function stepMove(window) {
    var state = moveStates[windowKey(window)];
    if (!state) {
        return;
    }

    maybeArmMoveState(state);
    state.last = cursorPoint();
    showSelectionOutline(window, state);
}

function finishMove(window) {
    var key = windowKey(window);
    var state = moveStates[key];
    if (!state) {
        return;
    }

    delete moveStates[key];
    if (!state.shift) {
        return;
    }

    state.last = cursorPoint();
    var selection = selectionForMove(window, state);
    window.setMaximize(false, false);
    detachFromTile(window);
    window.frameGeometry = selection.frame;
    remember(window, selection.start, selection.span);
    workspace.hideOutline();
}

function connectWindowSignals(window) {
    return;
}

function connectExistingWindows() {
    var windows = workspace.windowList ? workspace.windowList() : workspace.stackingOrder;

    for (var i = 0; i < windows.length; i++) {
        connectWindowSignals(windows[i]);
    }
}

function inferZone(window) {
    var state = remembered(window);
    if (state) {
        return state;
    }

    var area = usableArea(window);
    var geometry = window.frameGeometry;
    var unit = area.width / zoneCount;
    var start = Math.round((geometry.x - area.x) / unit);
    var end = Math.round((geometry.x + geometry.width - area.x) / unit);

    start = clamp(start, 0, zoneCount - 1);
    end = clamp(end, start + 1, zoneCount);

    return {
        count: zoneCount,
        start: start,
        span: end - start
    };
}

function moveBy(delta) {
    var window = activeWindow();
    if (!window || window.specialWindow || window.fullScreen) {
        return;
    }

    var state = inferZone(window);
    applyZone(clamp(state.start + delta, 0, zoneCount - state.span), state.span);
}

function growRight() {
    var window = activeWindow();
    if (!window || window.specialWindow || window.fullScreen) {
        return;
    }

    var state = inferZone(window);
    applyZone(state.start, clamp(state.span + 1, 1, zoneCount - state.start));
}

function shrinkRight() {
    var window = activeWindow();
    if (!window || window.specialWindow || window.fullScreen) {
        return;
    }

    var state = inferZone(window);
    applyZone(state.start, clamp(state.span - 1, 1, zoneCount - state.start));
}

function growLeft() {
    var window = activeWindow();
    if (!window || window.specialWindow || window.fullScreen) {
        return;
    }

    var state = inferZone(window);
    if (state.start === 0) {
        return;
    }
    applyZone(state.start - 1, state.span + 1);
}

function shrinkLeft() {
    var window = activeWindow();
    if (!window || window.specialWindow || window.fullScreen) {
        return;
    }

    var state = inferZone(window);
    if (state.span <= 1) {
        return;
    }
    applyZone(state.start + 1, state.span - 1);
}

function centerSpan(span) {
    span = clamp(span, 1, zoneCount);
    applyZone(Math.floor((zoneCount - span) / 2), span);
}

function setMode(count) {
    setLiveMode(count);
    callDBus(
        "org.powerhouse.UltrawideZones",
        "/org/powerhouse/UltrawideZones",
        "org.powerhouse.UltrawideZones",
        "SetMode",
        count,
        function(ok) {
            print("Ultrawide Zones: " + count + " columns service result: " + ok);
        }
    );
}

function loadMode() {
    callDBus(
        "org.powerhouse.UltrawideZones",
        "/org/powerhouse/UltrawideZones",
        "org.powerhouse.UltrawideZones",
        "GetMode",
        function(count) {
            if (isValidMode(count)) {
                setLiveMode(count);
            } else {
                setLiveMode(zoneCount);
            }
            print("Ultrawide Zones: loaded " + zoneCount + " columns");
        }
    );
}

function setOneOneThree() {
    setMode(5);
    var window = activeWindow();
    if (window && !window.specialWindow && !window.fullScreen) {
        applyZone(2, 3);
    }
}

registerShortcut("UltrawideZones3", "Ultrawide Zones: 3 Columns", "Meta+Alt+3", function() {
    setMode(3);
});

registerShortcut("UltrawideZones4", "Ultrawide Zones: 4 Columns", "Meta+Alt+4", function() {
    setMode(4);
});

registerShortcut("UltrawideZones5", "Ultrawide Zones: 5 Columns", "Meta+Alt+5", function() {
    setMode(5);
});

registerShortcut("UltrawideZones6", "Ultrawide Zones: 6 Columns", "Meta+Alt+6", function() {
    setMode(6);
});

registerShortcut("UltrawideZones7", "Ultrawide Zones: 7 Columns", "Meta+Alt+7", function() {
    setMode(7);
});

registerShortcut("UltrawideZones8", "Ultrawide Zones: 8 Columns", "Meta+Alt+8", function() {
    setMode(8);
});

registerShortcut("UltrawideZonesShiftDrag", "Ultrawide Zones: Shift Drag", "none", function() {
    armShiftDrag();
});

registerShortcut("UltrawideZonesSpanDrag", "Ultrawide Zones: Span Drag", "none", function() {
    armSpanDrag();
});

registerShortcut("UltrawideZonesReleaseDrag", "Ultrawide Zones: Release Drag", "none", function() {
    releaseDrag();
});

registerShortcut("UltrawideZonesMoveLeft", "Ultrawide Zones: Move Left", "Meta+Alt+Shift+A", function() {
    moveBy(-1);
});

registerShortcut("UltrawideZonesMoveRight", "Ultrawide Zones: Move Right", "Meta+Alt+Shift+D", function() {
    moveBy(1);
});

registerShortcut("UltrawideZonesGrowRight", "Ultrawide Zones: Grow Right", "Meta+Alt+Shift+Right", function() {
    growRight();
});

registerShortcut("UltrawideZonesShrinkRight", "Ultrawide Zones: Shrink Right", "Meta+Alt+Ctrl+Right", function() {
    shrinkRight();
});

registerShortcut("UltrawideZonesGrowLeft", "Ultrawide Zones: Grow Left", "Meta+Alt+Shift+Left", function() {
    growLeft();
});

registerShortcut("UltrawideZonesShrinkLeft", "Ultrawide Zones: Shrink Left", "Meta+Alt+Ctrl+Left", function() {
    shrinkLeft();
});

registerShortcut("UltrawideZonesCenter", "Ultrawide Zones: Center Span", "Meta+Alt+C", function() {
    centerSpan(Math.min(3, zoneCount));
});

registerShortcut("UltrawideZonesOneOneThree", "Ultrawide Zones: 1:1:3", "Meta+Alt+M", function() {
    setOneOneThree();
});

workspace.windowAdded.connect(function(window) {
    connectWindowSignals(window);
});
connectExistingWindows();
loadMode();
