// Legacy stubs – kept for backwards-compatibility with any remaining imports.
// The real implementations live in lib/core/widgets/aksa_widgets.dart

export 'aksa_widgets.dart' show AksaCard, SectionTitle, MacroProgressRow;

// InfoCard alias
import 'package:flutter/material.dart';
import 'aksa_widgets.dart';

// InfoCard is defined in aksa_widgets.dart already as a legacy alias.
// This file just re-exports to satisfy any old import paths.