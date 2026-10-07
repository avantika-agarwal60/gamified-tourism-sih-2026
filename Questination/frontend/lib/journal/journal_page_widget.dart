import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import 'journal_data.dart';

const _kPaper = Color(0xFFF9F9ED);
const _kBrown = Color(0xFF3A2810);
const _kBrownMid = Color(0xFF7A5830);
const _kBrownLight = Color(0xFFA08060);
const _kBorder = Color(0xFFC8B890);
const _kAccent = Color(0xFF8A7050);
const _kGreen = Color(0xFF2A4A20);
const _kSlotBg = Color(0xFFEDE0C4);

class PhotoSlotWidget extends StatefulWidget {
  final PhotoSlotData slot;
  final String? imagePath;
  final ValueChanged<XFile> onPhotoAdded;
  final bool squareCorners;

  const PhotoSlotWidget({
    super.key,
    required this.slot,
    required this.imagePath,
    required this.onPhotoAdded,
    this.squareCorners = false,
  });

  @override
  State<PhotoSlotWidget> createState() => _PhotoSlotWidgetState();
}

class _PhotoSlotWidgetState extends State<PhotoSlotWidget> {
  bool _hovered = false;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      widget.onPhotoAdded(picked);
    }
  }

  Widget _buildImage(String path) {
    final image = path.startsWith('http://') ||
            path.startsWith('https://') ||
            path.startsWith('blob:')
        ? Image.network(path, fit: BoxFit.cover)
        : Image.file(File(path), fit: BoxFit.cover);

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.393, 0.769, 0.189, 0, 0,
        0.349, 0.686, 0.168, 0, 0,
        0.272, 0.534, 0.131, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.imagePath != null && widget.imagePath!.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _pickPhoto,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _hovered && !hasPhoto ? const Color(0xFFE0D4B0) : _kSlotBg,
            borderRadius: BorderRadius.circular(widget.squareCorners ? 0 : 8),
            border: Border.all(
              color: _hovered ? _kGreen : _kAccent,
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _DashedBorderPainter(_hovered)),
              ),
              if (hasPhoto)
                _buildImage(widget.imagePath!)
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '+ ADD\nPHOTO',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.pressStart2p(
                        fontSize: 6,
                        color: _hovered ? _kGreen : _kAccent,
                        height: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.slot.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.vt323(
                        fontSize: 13,
                        color: _kBrownMid,
                      ),
                    ),
                  ],
                ),
              if (hasPhoto && _hovered)
                Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Text(
                    '▶ CHANGE',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 6,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final bool hovered;
  _DashedBorderPainter(this.hovered);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (hovered ? _kGreen : _kAccent).withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashLen = 5.0;
    const gapLen = 4.0;

    void drawDashedLine(Offset start, Offset end) {
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final total = (dx.abs() > dy.abs() ? dx.abs() : dy.abs());
      if (total == 0) return;
      final nx = dx / total;
      final ny = dy / total;

      double pos = 0;
      bool drawing = true;
      while (pos < total) {
        final segLen = drawing ? dashLen : gapLen;
        final next = (pos + segLen).clamp(0.0, total);
        if (drawing) {
          canvas.drawLine(
            Offset(start.dx + nx * pos, start.dy + ny * pos),
            Offset(start.dx + nx * next, start.dy + ny * next),
            paint,
          );
        }
        pos = next;
        drawing = !drawing;
      }
    }

    drawDashedLine(Offset.zero, Offset(size.width, 0));
    drawDashedLine(Offset(size.width, 0), Offset(size.width, size.height));
    drawDashedLine(Offset(size.width, size.height), Offset(0, size.height));
    drawDashedLine(Offset(0, size.height), Offset.zero);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.hovered != hovered;
}

class JournalPageWidget extends StatelessWidget {
  final JournalPageData page;
  final Map<String, String> photos;
  final ValueChanged<MapEntry<String, XFile>> onPhotoAdded;
  final int pageNum;
  final String? cityName;
  final int xpReward;
  final int coinsReward;
  final bool isEditingCaption;
  final String? captionDraft;
  final ValueChanged<String>? onCaptionChanged;
  final VoidCallback? onStickerTap;
  final VoidCallback? onCaptionEdit;
  final VoidCallback? onCaptionSave;
  final VoidCallback? onCaptionCancel;

  const JournalPageWidget({
    super.key,
    required this.page,
    required this.photos,
    required this.onPhotoAdded,
    required this.pageNum,
    required this.xpReward,
    required this.coinsReward,
    this.isEditingCaption = false,
    this.captionDraft,
    this.onCaptionChanged,
    this.cityName,
    this.onStickerTap,
    this.onCaptionEdit,
    this.onCaptionSave,
    this.onCaptionCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _kPaper,
        image: const DecorationImage(
          image: AssetImage('assets/journal page.png'),
          fit: BoxFit.fill,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Dear Diary',
                style: GoogleFonts.caveat(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: _kGreen,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              flex: 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: Transform.rotate(
                                  angle:-0.09,
                                  child: Container(
                                    margin: const EdgeInsets.all(5),
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x30000000),
                                          blurRadius: 8,
                                          offset: Offset(2, 4),
                                        ),
                                      ],
                                    ),
                                    child: _buildPhotoSlot(
                                      0,
                                      squareCorners: true,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -5,
                                bottom: 10,
                                child: Transform.rotate(
                                  angle: -0.16,
                                  child: Image.asset(
                                    'assets/explored stamp.png',
                                    width: 68,
                                    height: 58,
                                    fit: BoxFit.contain,
                                    semanticLabel: 'Explored',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${page.title},',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.specialElite(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: _kBrown,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 13,
                              color: _kGreen,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                cityName ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.specialElite(
                                  fontSize: 13,
                                  color: _kBrownMid,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: _buildCaption()),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'FOUND ITEMS',
                  style: GoogleFonts.pressStart2p(
                    fontSize: 6,
                    color: _kGreen,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.auto_awesome, color: Color(0xFF66834B), size: 14),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 68,
              child: Row(
                children: [
                  Expanded(
                    child: _buildFoundItem(
                      label: 'XP',
                      amount: '+$xpReward',
                      imagePath: 'assets/xp.png',
                      fallbackIcon: Icons.stars,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFoundItem(
                      label: 'COINS',
                      amount: '+$coinsReward',
                      imagePath: 'assets/coin.png',
                      fallbackIcon: Icons.toll,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            _buildStickerRow(pageNum),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: 0.04,
                child: SizedBox(
                  width: 145,
                  height: 125,
                  child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 102,
                      height: 81,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5AA45),
                        border: Border.all(
                          color: const Color(0xFF805520),
                          width: 2,
                        ),
                      ),
                    ),
                    if (page.badgeImagePath?.isNotEmpty == true)
                      Positioned.fill(
                        child: Center(
                          child: SizedBox(
                            width: 110,
                            height: 86,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: Image.network(
                                _absoluteImageUrl(page.badgeImagePath!),
                                width: 84,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: Color(0xFFD5AA45),
                                  child: Center(
                                    child: Icon(
                                      Icons.workspace_premium,
                                      size: 42,
                                      color: Color(0xFF805520),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const Icon(
                        Icons.workspace_premium,
                        size: 42,
                        color: Color(0xFF805520),
                      ),
                    Image.asset(
                      'assets/stamp for badge.png',
                      width: 195,
                      height: 169,
                      fit: BoxFit.fill,
                      semanticLabel: 'Quest badge frame',
                    ),
                  ],
                  ),
                ),
              ),
              if (page.date.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  page.date,
                  style: GoogleFonts.pressStart2p(
                    fontSize: 5,
                    color: _kGreen,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaption() {
    final caption = page.caption?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.format_quote_rounded, color: _kAccent, size: 18),
            const Spacer(),
            if (isEditingCaption) ...[
              IconButton(
                onPressed: onCaptionCancel,
                icon: const Icon(Icons.close, size: 17),
                color: _kBrownMid,
                tooltip: 'Cancel caption edit',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 28, height: 28),
              ),
              IconButton(
                onPressed: onCaptionSave,
                icon: const Icon(Icons.check, size: 17),
                color: _kGreen,
                tooltip: 'Save caption',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 28, height: 28),
              ),
            ] else
              IconButton(
                onPressed: onCaptionEdit,
                icon: const Icon(Icons.edit_outlined, size: 17),
                color: _kBrownMid,
                tooltip: 'Edit page caption',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 28, height: 28),
              ),
          ],
        ),
        Text(
          'A MOMENT FROM THE JOURNEY',
          style: GoogleFonts.pressStart2p(fontSize: 5, color: _kGreen),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: isEditingCaption
              ? TextFormField(
                  key: ValueKey('caption-editor-${page.title}'),
                  autofocus: true,
                  initialValue: captionDraft ?? caption,
                  onChanged: onCaptionChanged,
                  maxLength: 240,
                  maxLines: null,
                  expands: true,
                  textCapitalization: TextCapitalization.sentences,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.caveat(
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                    color: _kBrownMid,
                    height: 1.05,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Write a note about this quest',
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                )
              : SingleChildScrollView(
                  child: Transform.rotate(
                    angle: -0.035,
                    child: Text(
                      caption.isEmpty ? 'ADD A PAGE CAPTION' : caption,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.caveat(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                        color: caption.isEmpty ? _kBrownLight : _kBrownMid,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 1,
            child: _buildFunFactBox(),
          ),
        ),
      ],
    );
  }

  Widget _buildFunFactBox() {
    return AspectRatio(
      aspectRatio: 1.5,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            child: Image.asset(
              'assets/textbox.png',
              fit: BoxFit.fill,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '"I guided you here so we could play hide and seek"',
                style: TextStyle(
                  fontSize: 8,
                  color: _kBrown,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundItem({
    required String label,
    required String amount,
    required String imagePath,
    required IconData fallbackIcon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D4),
        border: Border.all(color: const Color(0xFFD1AE62), width: 1.5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            width: 30,
            height: 30,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              fallbackIcon,
              size: 25,
              color: const Color(0xFF9A7133),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.pressStart2p(
                  fontSize: 5,
                  color: _kBrownMid,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                amount,
                style: GoogleFonts.pressStart2p(
                  fontSize: 7,
                  color: _kBrown,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSlot(int index, {bool squareCorners = false}) {
    if (index >= page.slots.length) return const SizedBox.shrink();
    final slot = page.slots[index];
    return PhotoSlotWidget(
      key: ValueKey(slot.id),
      slot: slot,
      imagePath: photos[slot.id],
      onPhotoAdded: (photo) => onPhotoAdded(MapEntry(slot.id, photo)),
      squareCorners: squareCorners,
    );
  }

  String _absoluteImageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '${ApiService.baseUrl}$normalizedPath';
  }

  Widget _buildStickerRow(int num) {
    return Row(
      children: [
        if (page.stickerImagePath?.startsWith('preview-emoji:') ?? false)
          Text(
            page.stickerImagePath!.substring('preview-emoji:'.length),
            style: const TextStyle(fontSize: 20),
          )
        else if (page.stickerImagePath?.isNotEmpty ?? false)
          Image.network(
            _absoluteImageUrl(page.stickerImagePath!),
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ...page.stickers
            .map((s) => Text(s, style: const TextStyle(fontSize: 14))),
        if (onStickerTap != null)
          IconButton(
            onPressed: page.stickerOptions.isEmpty ? null : onStickerTap,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            color: _kBrownMid,
            tooltip: 'Choose a city sticker',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
        const Spacer(),
        Text(
          'P.$num',
          style: GoogleFonts.pressStart2p(fontSize: 5, color: _kBrownLight),
        ),
      ],
    );
  }
}

