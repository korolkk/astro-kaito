/**
 * Generate minimal H.264, H.265, and MP4 test bitstreams for the bitstream analyzer.
 * These are syntactically valid streams with recognizable NAL headers,
 * suitable for testing the parser's frame type detection and GOP analysis.
 *
 * Usage: node scripts/generate-test-streams.cjs
 * Output: test-streams/ directory
 */

const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'test-streams');
fs.mkdirSync(OUT, { recursive: true });

// ── Helpers ────────────────────────────────────────────────────────

function writeStartCode(buf, offset) {
	buf[offset] = 0x00;
	buf[offset + 1] = 0x00;
	buf[offset + 2] = 0x00;
	buf[offset + 3] = 0x01;
	return offset + 4;
}

/** Simple bit writer: appends bits to a byte buffer */
class BitWriter {
	constructor() {
		this.chunks = [];
		this.currentByte = 0;
		this.bitPos = 7; // MSB first, 7→0
	}
	writeBits(value, n) {
		for (let i = n - 1; i >= 0; i--) {
			const bit = (value >> i) & 1;
			this.currentByte |= (bit << this.bitPos);
			this.bitPos--;
			if (this.bitPos < 0) {
				this.chunks.push(this.currentByte);
				this.currentByte = 0;
				this.bitPos = 7;
			}
		}
	}
	writeUE(value) {
		// Unsigned Exp-Golomb
		if (value === 0) {
			this.writeBits(1, 1); // just the 1 bit
			return;
		}
		value++; // codeword = value + 1
		const leadingZeros = Math.floor(Math.log2(value));
		// Write leading zeros
		for (let i = 0; i < leadingZeros; i++) this.writeBits(0, 1);
		// Write the value (leadingZeros + 1 bits)
		const totalBits = leadingZeros + 1;
		this.writeBits(value, totalBits);
	}
	writeSE(value) {
		if (value <= 0) this.writeUE(-2 * value);
		else this.writeUE(2 * value - 1);
	}
	byteAlign() {
		if (this.bitPos < 7) {
			this.chunks.push(this.currentByte);
			this.currentByte = 0;
			this.bitPos = 7;
		}
	}
	toBytes() {
		this.byteAlign();
		return Buffer.from(this.chunks);
	}
}

// ── H.265 Generator ────────────────────────────────────────────────

function generateH265VPS() {
	const w = new BitWriter();
	w.writeBits(0, 4);  // vps_video_parameter_set_id
	w.writeBits(1, 1);  // vps_base_layer_internal_flag
	w.writeBits(1, 1);  // vps_base_layer_available_flag
	w.writeBits(0, 6);  // vps_max_layers_minus1
	w.writeBits(0, 3);  // vps_max_sub_layers_minus1
	w.writeBits(1, 1);  // vps_temporal_id_nesting_flag
	w.writeBits(0xFFFF, 16); // vps_reserved_0xffff_16bits
	// profile_tier_level(1, 0)
	writeProfileTierLevel(w, true, 0);
	w.writeBits(0, 1);  // vps_sub_layer_ordering_info_present_flag
	// No sub-layer ordering info since max_sub_layers_minus1 = 0
	w.writeBits(0, 8);  // vps_max_dec_pic_buffering_minus1[0]
	w.writeBits(0, 8);  // vps_max_num_reorder_pics[0]
	w.writeBits(0, 8);  // vps_max_latency_increase_plus1[0]
	w.writeBits(0, 6);  // vps_max_layer_id
	w.writeUE(0);        // vps_num_layer_sets_minus1
	w.writeBits(0, 1);  // vps_timing_info_present_flag
	w.writeBits(0, 1);  // vps_extension_flag
	return w.toBytes();
}

function writeProfileTierLevel(w, profilePresent, maxSubLayersMinus1) {
	if (profilePresent) {
		w.writeBits(0, 2);  // general_profile_space
		w.writeBits(0, 1);  // general_tier_flag (main tier)
		w.writeBits(1, 5);  // general_profile_idc (1 = Main)
		for (let i = 0; i < 32; i++) w.writeBits(0, 1); // compatibility flags
		w.writeBits(0, 1);  // general_progressive_source_flag
		w.writeBits(0, 1);  // general_interlaced_source_flag
		w.writeBits(0, 1);  // general_non_packed_constraint_flag
		w.writeBits(1, 1);  // general_frame_only_constraint_flag
		// 43 more constraint flags
		for (let i = 0; i < 43; i++) w.writeBits(i < 5 ? 1 : 0, 1);
		w.writeBits(0, 1);  // general_inbld_flag
	}
	w.writeBits(30, 8);   // general_level_idc (level 3.0)
	for (let i = 0; i < maxSubLayersMinus1; i++) {
		w.writeBits(0, 1); // sub_layer_profile_present_flag
		w.writeBits(0, 1); // sub_layer_level_present_flag
	}
	if (maxSubLayersMinus1 > 0) {
		for (let i = 0; i < 8 - maxSubLayersMinus1; i++) {
			w.writeBits(0, 2); // reserved
		}
	}
	// Skipping sub-layer profile/level data for simplicity
}

function generateH265SPS() {
	const w = new BitWriter();
	w.writeBits(0, 4);  // sps_video_parameter_set_id
	w.writeBits(0, 3);  // sps_max_sub_layers_minus1
	w.writeBits(1, 1);  // sps_temporal_id_nesting_flag
	writeProfileTierLevel(w, true, 0);
	w.writeUE(0);        // sps_seq_parameter_set_id
	w.writeUE(1);        // chroma_format_idc = 1 (4:2:0)
	w.writeUE(0);        // bit_depth_luma_minus8
	w.writeUE(0);        // bit_depth_chroma_minus8
	w.writeBits(0, 1);  // pcm_enabled_flag
	w.writeUE(0);        // log2_max_pic_order_cnt_lsb_minus4
	w.writeUE(0);        // sps_max_dec_pic_buffering_minus1
	w.writeUE(0);        // sps_max_num_reorder_pics
	w.writeUE(0);        // sps_max_latency_increase_plus1
	// Scaling list
	w.writeBits(0, 1);  // scaling_list_enabled_flag
	w.writeBits(0, 1);  // amp_enabled_flag
	w.writeBits(0, 1);  // sample_adaptive_offset_enabled_flag
	w.writeBits(0, 1);  // pcm_enabled_flag (already set)
	// ... more flags
	w.writeUE(0);        // num_short_term_ref_pic_sets
	w.writeBits(0, 1);  // long_term_ref_pics_present_flag
	w.writeBits(0, 1);  // sps_temporal_mvp_enabled_flag
	w.writeBits(0, 1);  // strong_intra_smoothing_enabled_flag
	w.writeBits(0, 1);  // vui_parameters_present_flag
	w.writeBits(0, 1);  // sps_extension_present_flag
	return w.toBytes();
}

function generateH265PPS() {
	const w = new BitWriter();
	w.writeUE(0);        // pps_pic_parameter_set_id
	w.writeUE(0);        // pps_seq_parameter_set_id
	w.writeBits(0, 1);  // dependent_slice_segments_enabled_flag
	w.writeBits(0, 1);  // output_flag_present_flag
	w.writeBits(0, 3);  // num_extra_slice_header_bits
	w.writeBits(0, 1);  // sign_data_hiding_enabled_flag
	w.writeBits(0, 1);  // cabac_init_present_flag
	w.writeUE(0);        // num_ref_idx_l0_default_active_minus1
	w.writeUE(0);        // num_ref_idx_l1_default_active_minus1
	w.writeSE(0);        // init_qp_minus26
	w.writeBits(0, 1);  // constrained_intra_pred_flag
	w.writeBits(0, 1);  // transform_skip_enabled_flag
	w.writeBits(0, 1);  // cu_qp_delta_enabled_flag
	w.writeUE(0);        // diff_cu_qp_delta_depth
	w.writeSE(0);        // pps_cb_qp_offset
	w.writeSE(0);        // pps_cr_qp_offset
	w.writeBits(0, 1);  // pps_slice_chroma_qp_offsets_present_flag
	w.writeBits(0, 1);  // weighted_pred_flag
	w.writeBits(0, 1);  // weighted_bipred_flag
	w.writeBits(0, 1);  // transquant_bypass_enabled_flag
	w.writeBits(0, 1);  // tiles_enabled_flag
	w.writeBits(0, 1);  // entropy_coding_sync_enabled_flag
	w.writeBits(0, 1);  // pps_loop_filter_across_slices_enabled_flag
	w.writeBits(0, 1);  // deblocking_filter_control_present_flag
	w.writeBits(0, 1);  // pps_scaling_list_data_present_flag
	w.writeBits(0, 1);  // lists_modification_present_flag
	w.writeUE(0);        // log2_parallel_merge_level_minus2
	w.writeBits(0, 1);  // slice_segment_header_extension_present_flag
	w.writeBits(0, 1);  // pps_extension_present_flag
	return w.toBytes();
}

function generateH265SliceHeader(isIDR, sliceType) {
	// sliceType: 0=B, 1=P, 2=I
	const w = new BitWriter();
	w.writeBits(1, 1);   // first_slice_segment_in_pic_flag
	if (isIDR) {
		w.writeBits(0, 1); // no_output_of_prior_pics_flag
	}
	w.writeUE(0);         // slice_pic_parameter_set_id
	// Not writing dependent_slice_segment_flag since first_slice = 1
	// Not writing slice_segment_address since first_slice = 1
	w.writeUE(sliceType);  // slice_type ← This is what the parser reads!
	// Minimal remaining fields for a complete header
	w.writeUE(0);         // pic_parameter_set_id (already? no, just fill)
	w.writeBits(0, 5);    // minimal slice QP etc.
	return w.toBytes();
}

function makeH265NALUnit(type, payload) {
	// Build 2-byte NAL header: forbidden(1)=0 | type(6) | layer_id(6)=0 | temporal_id+1(3)=1
	const header0 = ((type << 1) & 0xFE); // top 7 bits: 0 | type[5:0]
	const header1 = 0x01; // layer_id=0, temporal_id=0 → temporal_id_plus1=1
	const nal = Buffer.alloc(2 + payload.length);
	nal[0] = header0;
	nal[1] = header1;
	payload.copy(nal, 2);
	return nal;
}

function buildAnnexBStream(nalUnits) {
	const chunks = [];
	const startCode = Buffer.from([0x00, 0x00, 0x00, 0x01]);
	for (const nalu of nalUnits) {
		chunks.push(startCode);
		chunks.push(nalu);
	}
	return Buffer.concat(chunks);
}

function generateH265Raw() {
	console.log('Generating H.265 raw bitstream...');

	const vpsData = generateH265VPS();
	const spsData = generateH265SPS();
	const ppsData = generateH265PPS();

	// Generate frames with GOP pattern: I P P P I P P P
	// This gives 2 GOPs of size 4 each
	const frames = [
		{ isIDR: true,  sliceType: 2 }, // I frame (GOP 1 start)
		{ isIDR: false, sliceType: 1 }, // P frame
		{ isIDR: false, sliceType: 1 }, // P frame
		{ isIDR: false, sliceType: 1 }, // P frame
		{ isIDR: true,  sliceType: 2 }, // I frame (GOP 2 start)
		{ isIDR: false, sliceType: 1 }, // P frame
		{ isIDR: false, sliceType: 1 }, // P frame
		{ isIDR: false, sliceType: 1 }, // P frame
	];

	const nalUnits = [];
	nalUnits.push(makeH265NALUnit(32, vpsData));  // VPS
	nalUnits.push(makeH265NALUnit(33, spsData));  // SPS
	nalUnits.push(makeH265NALUnit(34, ppsData));  // PPS

	for (let i = 0; i < frames.length; i++) {
		const f = frames[i];
		const nalType = f.isIDR ? 19 : 1; // IDR_W_RADL : TRAIL_R
		const sh = generateH265SliceHeader(f.isIDR, f.sliceType);
		// Add some dummy coded data after the slice header
		const dummyData = Buffer.alloc(10 + f.sliceType * 15); // different sizes for I/P
		const payload = Buffer.concat([sh, dummyData]);
		nalUnits.push(makeH265NALUnit(nalType, payload));
	}

	return buildAnnexBStream(nalUnits);
}

// ── H.264 Generator ────────────────────────────────────────────────

function generateH264SPS() {
	const w = new BitWriter();
	w.writeBits(66, 8);    // profile_idc = Baseline
	w.writeBits(0, 1);     // constraint_set0_flag
	w.writeBits(0, 1);     // constraint_set1_flag
	w.writeBits(0, 1);     // constraint_set2_flag
	w.writeBits(0, 1);     // constraint_set3_flag
	w.writeBits(0, 1);     // constraint_set4_flag
	w.writeBits(0, 1);     // constraint_set5_flag
	w.writeBits(0, 2);     // reserved_zero_2bits
	w.writeBits(30, 8);    // level_idc = 3.0
	w.writeUE(0);           // seq_parameter_set_id
	w.writeUE(0);           // log2_max_frame_num_minus4
	w.writeUE(0);           // pic_order_cnt_type
	w.writeUE(0);           // log2_max_pic_order_cnt_lsb_minus4
	w.writeUE(0);           // num_ref_frames
	w.writeBits(0, 1);     // gaps_in_frame_num_value_allowed_flag
	w.writeUE(3);           // pic_width_in_mbs_minus1 → 64 pixels
	w.writeUE(3);           // pic_height_in_map_units_minus1 → 64 pixels
	w.writeBits(1, 1);     // frame_mbs_only_flag
	w.writeBits(0, 1);     // direct_8x8_inference_flag
	w.writeBits(0, 1);     // frame_cropping_flag
	w.writeBits(0, 1);     // vui_parameters_present_flag
	return w.toBytes();
}

function generateH264PPS() {
	const w = new BitWriter();
	w.writeUE(0);           // pic_parameter_set_id
	w.writeUE(0);           // seq_parameter_set_id
	w.writeBits(0, 1);     // entropy_coding_mode_flag (CAVLC)
	w.writeBits(0, 1);     // bottom_field_pic_order_in_frame_present_flag
	w.writeUE(0);           // num_slice_groups_minus1
	w.writeUE(0);           // num_ref_idx_l0_default_active_minus1
	w.writeUE(0);           // num_ref_idx_l1_default_active_minus1
	w.writeBits(0, 1);     // weighted_pred_flag
	w.writeBits(0, 2);     // weighted_bipred_idc
	w.writeSE(0);           // pic_init_qp_minus26
	w.writeSE(0);           // pic_init_qs_minus26
	w.writeSE(0);           // chroma_qp_index_offset
	w.writeBits(0, 1);     // deblocking_filter_control_present_flag
	w.writeBits(0, 1);     // constrained_intra_pred_flag
	w.writeBits(0, 1);     // redundant_pic_cnt_present_flag
	return w.toBytes();
}

function generateH264SliceHeader(isIDR, sliceTypeUE) {
	// sliceTypeUE: 2,7=I  0,5=P  1,6=B
	const w = new BitWriter();
	w.writeUE(0);             // first_mb_in_slice
	w.writeUE(sliceTypeUE);    // slice_type ← Key field for parser!
	w.writeUE(0);             // pic_parameter_set_id
	w.writeBits(0, 4);       // frame_num (log2_max_frame_num_minus4=0 → 4 bits)
	return w.toBytes();
}

function makeH264NALUnit(type, refIdc, payload) {
	const header = Buffer.alloc(1);
	header[0] = ((refIdc & 0x03) << 5) | (type & 0x1F);
	return Buffer.concat([header, payload]);
}

function generateH264Raw() {
	console.log('Generating H.264 raw bitstream...');

	const spsData = generateH264SPS();
	const ppsData = generateH264PPS();

	// GOP pattern: I P B P I P B  → 2 GOPs
	const frames = [
		{ isIDR: true,  sliceTypeUE: 2 }, // I
		{ isIDR: false, sliceTypeUE: 5 }, // P
		{ isIDR: false, sliceTypeUE: 6 }, // B
		{ isIDR: false, sliceTypeUE: 5 }, // P
		{ isIDR: true,  sliceTypeUE: 7 }, // I (GOP 2)
		{ isIDR: false, sliceTypeUE: 0 }, // P
		{ isIDR: false, sliceTypeUE: 1 }, // B
	];

	const nalUnits = [];
	nalUnits.push(makeH264NALUnit(7, 3, spsData));   // SPS, high priority
	nalUnits.push(makeH264NALUnit(8, 3, ppsData));   // PPS, high priority

	for (let i = 0; i < frames.length; i++) {
		const f = frames[i];
		const nalType = f.isIDR ? 5 : 1;
		const refIdc = f.sliceTypeUE === 1 || f.sliceTypeUE === 6 ? 1 : 2;
		const sh = generateH264SliceHeader(f.isIDR, f.sliceTypeUE);
		const dummyData = Buffer.alloc(15 + f.sliceTypeUE * 10);
		nalUnits.push(makeH264NALUnit(nalType, refIdc, Buffer.concat([sh, dummyData])));
	}

	return buildAnnexBStream(nalUnits);
}

// ── MP4 (H.265) Generator ──────────────────────────────────────────

function buildU32BE(v) {
	const b = Buffer.alloc(4);
	b.writeUInt32BE(v, 0);
	return b;
}

function buildBox(type, data) {
	const btype = Buffer.from(type);
	const size = 8 + data.length;
	return Buffer.concat([buildU32BE(size), btype, data]);
}

function buildFullBox(type, version, flags, data) {
	const btype = Buffer.from(type);
	const size = 12 + data.length;
	const flagsBuf = Buffer.alloc(3);
	flagsBuf[0] = (flags >> 16) & 0xFF;
	flagsBuf[1] = (flags >> 8) & 0xFF;
	flagsBuf[2] = flags & 0xFF;
	return Buffer.concat([buildU32BE(size), btype, Buffer.from([version]), flagsBuf, data]);
}

function makeHVCCBox(vps, sps, pps) {
	// HEVCDecoderConfigurationRecord
	const arrays = [];
	// Array of VPS
	let vpsNalus = [];
	for (const v of vps) vpsNalus.push(v);
	// Array of SPS
	let spsNalus = [];
	for (const s of sps) spsNalus.push(s);
	// Array of PPS
	let ppsNalus = [];
	for (const p of pps) ppsNalus.push(p);

	const paramArrays = [
		{ type: 0, nalus: vpsNalus },
		{ type: 1, nalus: spsNalus },
		{ type: 2, nalus: ppsNalus }
	];

	let arraysDataLen = 0;
	for (const arr of paramArrays) {
		arraysDataLen += 3; // array_completeness(1)+reserved(1)+type(6) + numNalus(16)
		for (const nalu of arr.nalus) {
			arraysDataLen += 2 + nalu.length; // nalUnitLength(16) + data
		}
	}

	const totalSize = 23 + arraysDataLen;
	const buf = Buffer.alloc(totalSize);
	let pos = 0;

	buf[pos++] = 1; // configurationVersion
	// general_profile_space(2)+tier(1)+profile(5) = 8 bits
	buf[pos++] = (0 << 6) | (0 << 5) | 1; // main profile
	// profile compatibility flags (4 bytes)
	buf[pos++] = 0; buf[pos++] = 0; buf[pos++] = 0; buf[pos++] = 0;
	// constraint indicator flags (6 bytes)
	for (let i = 0; i < 6; i++) buf[pos++] = (i < 5 ? 0x80 : 0x00);
	buf[pos++] = 30; // general_level_idc = 3.0
	// min_spatial_segmentation_idc (12 bits) + reserved(4)
	buf[pos++] = 0xF0; buf[pos++] = 0x00;
	// parallelismType(2) + reserved(6)
	buf[pos++] = 0xFC;
	// chroma_format_idc(2) + reserved(6)
	buf[pos++] = 0xFC;
	// bit_depth_luma_minus8(3) + reserved(5)
	buf[pos++] = 0xF8;
	// bit_depth_chroma_minus8(3) + reserved(5)
	buf[pos++] = 0xF8;
	// avgFrameRate (16 bits)
	buf[pos++] = 0x00; buf[pos++] = 0x00;
	// constantFrameRate(2)+numTemporalLayers(3)+temporalIdNested(1)+lengthSizeMinusOne(2)
	buf[pos++] = 0x03; // lengthSizeMinusOne = 3
	// numOfArrays
	buf[pos++] = paramArrays.length;

	for (const arr of paramArrays) {
		buf[pos++] = (0x80 | (arr.type & 0x0F)); // completeness + type
		const count = arr.nalus.length;
		buf[pos++] = (count >> 8) & 0xFF;
		buf[pos++] = count & 0xFF;
		for (const nalu of arr.nalus) {
			buf[pos++] = (nalu.length >> 8) & 0xFF;
			buf[pos++] = nalu.length & 0xFF;
			nalu.copy(buf, pos);
			pos += nalu.length;
		}
	}

	return buf;
}

	function makeAVC1SampleEntry(hvcC) {
		// Build codec config box (size + type + data)
		const configBoxType = Buffer.from('hvcC');
		const configBoxSize = 8 + hvcC.length;
		const hvcCBox = Buffer.alloc(configBoxSize);
		hvcCBox.writeUInt32BE(configBoxSize, 0);
		configBoxType.copy(hvcCBox, 4);
		hvcC.copy(hvcCBox, 8);

		// VisualSampleEntry fields (after entry header + SampleEntry fields)
		const visual = Buffer.alloc(70);
		visual.fill(0);
		visual.writeUInt16BE(64, 16);   // width = 64
		visual.writeUInt16BE(64, 18);   // height = 64
		visual.writeUInt32BE(0x00480000, 20); // horizresolution 72dpi
		visual.writeUInt32BE(0x00480000, 24); // vertresolution 72dpi
		visual.writeUInt16BE(1, 32);    // frame_count = 1
		visual.writeUInt16BE(0x0018, 66); // depth = 24-bit
		visual.writeInt16BE(-1, 68);    // pre_defined = -1

		// Build full sample entry:
		//   entry_size(4) + entry_type(4) +
		//   SampleEntry: reserved(6) + data_reference_index(2) +
		//   VisualSampleEntry: visual(70) +
		//   hvcC box
		const entrySize = 8 + 6 + 2 + 70 + hvcCBox.length;
		const entry = Buffer.alloc(entrySize);
		entry.writeUInt32BE(entrySize, 0);
		entry[4] = 0x68; entry[5] = 0x76; entry[6] = 0x63; entry[7] = 0x31; // 'hvc1'
		// SampleEntry: reserved(6) = 0
		entry.writeUInt16BE(1, 14);  // data_reference_index = 1
		visual.copy(entry, 16);       // VisualSampleEntry fields
		hvcCBox.copy(entry, 16 + 70); // codec config box

		return entry;
	}

function generateH265MP4() {
	console.log('Generating MP4 (H.265) ...');

	// Reuse H.265 codec data
	const vpsData = generateH265VPS();
	const spsData = generateH265SPS();
	const ppsData = generateH265PPS();

	const vpsNalu = makeH265NALUnit(32, vpsData);
	const spsNalu = makeH265NALUnit(33, spsData);
	const ppsNalu = makeH265NALUnit(34, ppsData);

	// Build hvcC box
	const hvcC = makeHVCCBox([vpsData], [spsData], [ppsData]);

	// Build sample entry
	const sampleEntry = makeAVC1SampleEntry(hvcC);  // hvcC = raw config data, gets box-wrapped inside

	// Generate slice NALUs
	const frameDefs = [
		{ isIDR: true,  sliceType: 2 }, // I
		{ isIDR: false, sliceType: 1 }, // P
		{ isIDR: false, sliceType: 1 }, // P
		{ isIDR: false, sliceType: 0 }, // B
		{ isIDR: true,  sliceType: 2 }, // I
		{ isIDR: false, sliceType: 1 }, // P
		{ isIDR: false, sliceType: 1 }, // P
		{ isIDR: false, sliceType: 0 }, // B
		{ isIDR: true,  sliceType: 2 }, // I
		{ isIDR: false, sliceType: 1 }, // P
	];

	const sliceNALUs = [];
	const sampleSizes = [];
	const syncSamples = [];
	let dts = 0;

	for (let i = 0; i < frameDefs.length; i++) {
		const f = frameDefs[i];
		const nalType = f.isIDR ? 19 : 1;
		const sh = generateH265SliceHeader(f.isIDR, f.sliceType);
		const dummyData = Buffer.alloc(20 + f.sliceType * 10);
		const nalu = makeH265NALUnit(nalType, Buffer.concat([sh, dummyData]));
		sliceNALUs.push(nalu);
	}

	// Build mdat (AVCC format: 4-byte length prefix + NALU)
	const mdatChunks = [];
	for (const nalu of sliceNALUs) {
		mdatChunks.push(buildU32BE(nalu.length));
		mdatChunks.push(nalu);
	}
	const mdatData = Buffer.concat(mdatChunks);

	// Build ftyp
	const ftypData = Buffer.alloc(20);
	ftypData.writeUInt32BE(20, 0);
	ftypData[4] = 0x66; ftypData[5] = 0x74; ftypData[6] = 0x79; ftypData[7] = 0x70; // 'ftyp'
	ftypData[8] = 0x68; ftypData[9] = 0x76; ftypData[10] = 0x63; ftypData[11] = 0x31; // 'hvc1'
	ftypData.writeUInt32BE(0, 12); // minor version
	ftypData[16] = 0x68; ftypData[17] = 0x76; ftypData[18] = 0x63; ftypData[19] = 0x31; // compatible

	// Build moov
	const stsdData = Buffer.concat([buildU32BE(1), sampleEntry]);  // entry_count + entries (version+flags from buildFullBox)
	const stsd = buildFullBox('stsd', 0, 0, Buffer.concat([stsdData]));

	// stts: all frames, delta = 1000 (at 30fps timescale)
	const sttsData = Buffer.alloc(12);
	sttsData.writeUInt32BE(1, 0); // 1 entry
	sttsData.writeUInt32BE(frameDefs.length, 4); // all samples
	sttsData.writeUInt32BE(1000, 8); // 1000 ticks per sample
	const stts = buildFullBox('stts', 0, 0, sttsData);

	// stss: sync sample indices (1-based)
	const stssEntries = [];
	for (let i = 0; i < frameDefs.length; i++) {
		if (frameDefs[i].isIDR) stssEntries.push(i + 1);
	}
	const stssData = Buffer.alloc(4 + stssEntries.length * 4);
	stssData.writeUInt32BE(stssEntries.length, 0);
	for (let i = 0; i < stssEntries.length; i++) {
		stssData.writeUInt32BE(stssEntries[i], 4 + i * 4);
	}
	const stss = buildFullBox('stss', 0, 0, stssData);

	// stsz: variable sample sizes
	const stszData = Buffer.alloc(8 + sliceNALUs.length * 4);
	stszData.writeUInt32BE(0, 0); // variable sizes
	stszData.writeUInt32BE(sliceNALUs.length, 4);
	for (let i = 0; i < sliceNALUs.length; i++) {
		stszData.writeUInt32BE(4 + sliceNALUs[i].length, 8 + i * 4); // +4 for AVCC length prefix
	}
	const stsz = buildFullBox('stsz', 0, 0, stszData);

	// stco: single chunk at offset = ftyp_size + mdat_header(8) + mdat_size(4)
	// Actually: offset into file where mdat data starts
	// ftyp = 20 bytes, mdat box header = 8 bytes → offset = 28
	const stcoData = Buffer.alloc(8);
	stcoData.writeUInt32BE(1, 0); // 1 chunk
	stcoData.writeUInt32BE(28, 4); // absolute offset to sample data
	const stco = buildFullBox('stco', 0, 0, stcoData);

	// Assemble stbl
	const stblData = Buffer.concat([stsd, stts, stss, stsz, stco]);
	const stbl = buildBox('stbl', stblData);

	// vmhd
	const vmhdData = Buffer.alloc(8);
	vmhdData.writeUInt16BE(0, 0); // graphicsmode
	vmhdData.writeUInt16BE(0, 2); // opcolor R
	vmhdData.writeUInt16BE(0, 4); // opcolor G
	vmhdData.writeUInt16BE(0, 6); // opcolor B
	const vmhd = buildFullBox('vmhd', 0, 1, vmhdData);

	// dinf → dref → url
	const urlBox = buildFullBox('url ', 0, 1, Buffer.alloc(0));
	const drefData = Buffer.concat([buildU32BE(0), buildU32BE(1), urlBox]);
	const dref = buildFullBox('dref', 0, 0, Buffer.concat([drefData]));
	const dinf = buildBox('dinf', dref);

	// minf
	const minfData = Buffer.concat([vmhd, dinf, stbl]);
	const minf = buildBox('minf', minfData);

	// mdhd
	const timescale = 30000;
	const duration = frameDefs.length * 1000; // 1000 ticks per frame
	const mdhdData = Buffer.alloc(20);
	const now = Math.floor(Date.now() / 1000);
	mdhdData.writeUInt32BE(now, 0); // creation_time
	mdhdData.writeUInt32BE(now, 4); // modification_time
	mdhdData.writeUInt32BE(timescale, 8);
	mdhdData.writeUInt32BE(duration, 12);
	mdhdData.writeUInt16BE(0x55C4, 16); // language: und
	mdhdData.writeUInt16BE(0, 18);
	const mdhd = buildFullBox('mdhd', 0, 0, mdhdData);

	// hdlr
	const hdlrData = Buffer.alloc(33);
	hdlrData.fill(0);
	hdlrData[4] = 0x76; hdlrData[5] = 0x69; hdlrData[6] = 0x64; hdlrData[7] = 0x65; // 'vide'
	const hdlr = buildFullBox('hdlr', 0, 0, hdlrData);

	// mdia
	const mdiaData = Buffer.concat([mdhd, hdlr, minf]);
	const mdia = buildBox('mdia', mdiaData);

	// tkhd
	const tkhdData = Buffer.alloc(84);
	tkhdData.writeUInt32BE(now, 0); // creation_time
	tkhdData.writeUInt32BE(now, 4); // modification_time
	tkhdData.writeUInt32BE(1, 8); // track_id = 1
	tkhdData.writeUInt32BE(0, 12); // reserved
	tkhdData.writeUInt32BE(duration, 16); // duration
	tkhdData.fill(0, 20, 28); // reserved
	tkhdData.writeUInt16BE(0, 28); // layer
	tkhdData.writeUInt16BE(0, 30); // alternate_group
	tkhdData.writeUInt16BE(0x0100, 32); // volume
	tkhdData.writeUInt16BE(0, 34); // reserved
	// unity matrix (36 bytes)
	tkhdData.fill(0, 36, 72);
	tkhdData.writeUInt32BE(0x00010000, 40);
	tkhdData.writeUInt32BE(0x00010000, 56);
	tkhdData.writeUInt32BE(0x40000000, 72);
	tkhdData.writeUInt32BE(0x00400000, 76); // width = 64 in 16.16
	tkhdData.writeUInt32BE(0x00400000, 80); // height = 64 in 16.16
	const tkhd = buildFullBox('tkhd', 0, 3, tkhdData);

	// trak
	const trakData = Buffer.concat([tkhd, mdia]);
	const trak = buildBox('trak', trakData);

	// mvhd
	const mvhdData = Buffer.alloc(96);
	mvhdData.writeUInt32BE(now, 0); // creation_time
	mvhdData.writeUInt32BE(now, 4); // modification_time
	mvhdData.writeUInt32BE(timescale, 8);
	mvhdData.writeUInt32BE(duration, 12);
	mvhdData.writeUInt32BE(0x00010000, 16); // rate 1.0
	mvhdData.writeUInt16BE(0x0100, 20); // volume 1.0
	mvhdData.fill(0, 22, 32);
	// unity matrix
	mvhdData.fill(0, 32, 68);
	mvhdData.writeUInt32BE(0x00010000, 36);
	mvhdData.writeUInt32BE(0x00010000, 52);
	mvhdData.writeUInt32BE(0x40000000, 68);
	mvhdData.fill(0, 72, 96);
	const mvhd = buildFullBox('mvhd', 0, 0, mvhdData);

	// moov
	const moovData = Buffer.concat([mvhd, trak]);
	const moov = buildBox('moov', moovData);

	// mdat box
	const mdat = buildBox('mdat', mdatData);

	// Final MP4: ftyp + mdat + moov
	return Buffer.concat([ftypData, mdat, moov]);
}

// ── Main ───────────────────────────────────────────────────────────

const h265Raw = generateH265Raw();
const h264Raw = generateH264Raw();
const mp4H265 = generateH265MP4();

const h265Path = path.join(OUT, 'test.h265');
const h264Path = path.join(OUT, 'test.h264');
const mp4Path = path.join(OUT, 'test_h265.mp4');

fs.writeFileSync(h265Path, h265Raw);
console.log(`  ✓ ${h265Path} (${h265Raw.length} bytes, ${h265Raw.length} B)`);

fs.writeFileSync(h264Path, h264Raw);
console.log(`  ✓ ${h264Path} (${h264Raw.length} bytes, ${h264Raw.length} B)`);

fs.writeFileSync(mp4Path, mp4H265);
console.log(`  ✓ ${mp4Path} (${mp4H265.length} bytes, ${mp4H265.length} B)`);

console.log('\nTest stream summary:');
console.log('  test.h265      — H.265 raw Annex B (8 frames: I P P P I P P P)');
console.log('  test.h264      — H.264 raw Annex B (7 frames: I P B P I P B)');
console.log('  test_h265.mp4  — MP4 with H.265  (10 frames: I P P B I P P B I P)');
console.log('\nDone!');
