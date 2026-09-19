import 'dart:convert';

import 'garment_tag.dart';
import 'magazine.dart';

/// How far along a make is.
///
/// Stored as [name], because the export is meant to be readable by hand and
/// "sewing" in a file says more than 2.
enum MakeStatus {
  queued('Queued'),
  cutting('Cutting'),
  sewing('Sewing'),
  done('Done');

  const MakeStatus(this.label);

  final String label;

  bool get isQueued => this == MakeStatus.queued;

  /// Cut out, or under the needle. The two the journal puts at the top,
  /// because they are the only ones waiting on her.
  bool get isUnderway =>
      this == MakeStatus.cutting || this == MakeStatus.sewing;

  bool get isDone => this == MakeStatus.done;

  /// Anything unrecognised, including null, is queued: a row the app cannot
  /// read is something she meant to make, not something she finished.
  static MakeStatus parse(Object? value) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    return MakeStatus.queued;
  }
}

/// One thing she is making, or means to make, or made.
///
/// The sew queue is this with [status] queued, not a second model: starting a
/// make is a status change, so every word written while it sat waiting is still
/// attached when it goes under the needle. A second table would have needed the
/// same issue, pattern, size and fabric fields, and would have made "start
/// sewing" a copy between tables, which is where data goes missing.
///
/// [magazineId] is a soft reference with no foreign key behind it. A finished
/// garment is hers and does not stop existing because the issue left the shelf,
/// and the re-seed deliberately brings a deleted issue back, so a dangling id
/// re-attaches by itself when that happens.
class Make {
  const Make({
    required this.id,
    required this.queuedOn,
    this.magazineId,
    this.patternNo = '',
    this.garment,
    this.size = '',
    this.fabric = '',
    this.status = MakeStatus.queued,
    this.notes = '',
    this.photos = const [],
    this.startedOn,
    this.finishedOn,
  });

  final String id;

  /// The issue the pattern came out of, or null for one from anywhere else.
  final String? magazineId;

  /// The pattern's number as Burda prints it. Free text: it is sometimes
  /// "118 B".
  final String patternNo;

  /// What it makes. Null until she says, which is most of the queue.
  final GarmentTag? garment;

  /// Free text, because she cuts a 38 bust and a 40 hip and writes both down.
  final String size;

  final String fabric;
  final MakeStatus status;
  final String notes;

  /// Absolute paths of photos of this make.
  final List<String> photos;

  final DateTime queuedOn;
  final DateTime? startedOn;
  final DateTime? finishedOn;

  /// What the journal calls it.
  ///
  /// The garment first, because that is how she thinks of it; the pattern
  /// number when she named no garment; and a plain phrase when there is
  /// neither, which is what a row queued in a hurry looks like.
  String get name => switch (garment) {
    final tag? => tag.one,
    _ when patternNo.isNotEmpty => 'Pattern $patternNo',
    _ => 'A make',
  };

  /// The moment the journal files it under: the last thing that happened to it.
  DateTime get sortDate => finishedOn ?? startedOn ?? queuedOn;

  bool get hasPhotos => photos.isNotEmpty;

  /// True when nothing but the status has been written down.
  bool get isBlank =>
      garment == null &&
      patternNo.isEmpty &&
      size.isEmpty &&
      fabric.isEmpty &&
      notes.isEmpty;

  /// The line beside the name: where the pattern came from and what she cut.
  ///
  /// [magazine] is null on the issue screen, where saying which issue it came
  /// from would be repeating the page it is printed on.
  String subtitle(Magazine? magazine) => [
    if (magazine != null) 'No. ${magazine.issue} / ${magazine.year}',
    if (patternNo.isNotEmpty) 'pattern $patternNo',
    if (size.isNotEmpty) 'size $size',
  ].join(' · ');

  /// The same make moved to [status], with the dates that move implies.
  ///
  /// The stamps are put on here rather than by whoever tapped, because four
  /// chips on the make screen and a save in the sheet all have to agree.
  /// Moving back clears the stamp it had put on: a make dragged out of Done was
  /// not finished, and leaving the date would have the journal print a
  /// finishing date for something still on the table. Reaching Done fills in a
  /// start she never recorded, which is how a garment sewn in 2019 and written
  /// up tonight gets one.
  Make withStatus(MakeStatus status, {DateTime? now}) {
    final at = now ?? DateTime.now();
    return switch (status) {
      MakeStatus.queued => copyWith(
        status: status,
        clearStartedOn: true,
        clearFinishedOn: true,
      ),
      MakeStatus.cutting || MakeStatus.sewing => copyWith(
        status: status,
        startedOn: startedOn ?? at,
        clearFinishedOn: true,
      ),
      MakeStatus.done => copyWith(
        status: status,
        startedOn: startedOn ?? at,
        finishedOn: finishedOn ?? at,
      ),
    };
  }

  /// Reads a row of the `makes` table.
  factory Make.fromMap(Map<String, Object?> map) => Make(
    id: map['id'] as String,
    magazineId: map['magazineId'] as String?,
    patternNo: map['patternNo'] as String? ?? '',
    garment: GarmentTag.parse(map['garment']),
    size: map['size'] as String? ?? '',
    fabric: map['fabric'] as String? ?? '',
    status: MakeStatus.parse(map['status']),
    notes: map['notes'] as String? ?? '',
    photos: _parsePhotos(map['photos']),
    queuedOn:
        _parseDate(map['queuedOn']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    startedOn: _parseDate(map['startedOn']),
    finishedOn: _parseDate(map['finishedOn']),
  );

  /// An exported make has the row's own shape with the photo list decoded, and
  /// [_parsePhotos] takes both, so one factory reads both.
  factory Make.fromJson(Map<String, dynamic> json) => Make.fromMap(json);

  Map<String, Object?> toMap() => {
    'id': id,
    'magazineId': magazineId,
    'patternNo': patternNo,
    'garment': garment?.name ?? '',
    'size': size,
    'fabric': fabric,
    'status': status.name,
    'notes': notes,
    'photos': jsonEncode(photos),
    'queuedOn': queuedOn.toIso8601String(),
    'startedOn': startedOn?.toIso8601String(),
    'finishedOn': finishedOn?.toIso8601String(),
  };

  /// Export shape: the row, with the photo list inline so the file reads.
  Map<String, Object?> toJson() => {...toMap(), 'photos': photos};

  Make copyWith({
    /// Settable because the queue is ordered by it: moving one up the list is
    /// a re-stamp rather than a position column every other write would have
    /// to maintain.
    DateTime? queuedOn,
    String? magazineId,
    bool clearMagazineId = false,
    String? patternNo,
    GarmentTag? garment,
    bool clearGarment = false,
    String? size,
    String? fabric,
    MakeStatus? status,
    String? notes,
    List<String>? photos,
    DateTime? startedOn,
    bool clearStartedOn = false,
    DateTime? finishedOn,
    bool clearFinishedOn = false,
  }) => Make(
    id: id,
    queuedOn: queuedOn ?? this.queuedOn,
    magazineId: clearMagazineId ? null : (magazineId ?? this.magazineId),
    patternNo: patternNo ?? this.patternNo,
    garment: clearGarment ? null : (garment ?? this.garment),
    size: size ?? this.size,
    fabric: fabric ?? this.fabric,
    status: status ?? this.status,
    notes: notes ?? this.notes,
    photos: photos ?? this.photos,
    startedOn: clearStartedOn ? null : (startedOn ?? this.startedOn),
    finishedOn: clearFinishedOn ? null : (finishedOn ?? this.finishedOn),
  );

  static DateTime? _parseDate(Object? value) => switch (value) {
    String value => DateTime.tryParse(value),
    int value => DateTime.fromMillisecondsSinceEpoch(value),
    _ => null,
  };

  /// Accepts both the stored JSON string and an already decoded list, the way
  /// [Magazine] reads its own photos.
  static List<String> _parsePhotos(Object? value) {
    switch (value) {
      case List value:
        return value.cast<String>();
      case String value when value.isNotEmpty:
        final decoded = jsonDecode(value);
        return decoded is List ? decoded.cast<String>() : const [];
      default:
        return const [];
    }
  }
}
