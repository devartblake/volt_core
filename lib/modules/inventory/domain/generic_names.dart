import '../../materials/domain/material_item.dart';
import 'catalog_part.dart';

/// True when [part]'s name is only a generic label rather than a real
/// description: it equals (ignoring case and spacing) the label of the part's
/// own slot, or the label of any material slot ("Battery", "Block heater").
bool hasGenericName(CatalogPart part) {
  final name = _norm(part.name);
  if (name.isEmpty) return false;
  if (part.slot != null && name == _norm(part.slot!.label)) return true;
  return MaterialSlot.values.any((s) => name == _norm(s.label));
}

/// The parts whose name is a generic slot label and should be blanked.
List<CatalogPart> partsWithGenericNames(Iterable<CatalogPart> parts) =>
    [for (final p in parts) if (hasGenericName(p)) p];

String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
