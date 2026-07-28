<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="AccordionGridProject.Default" %>

<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>POA Grid – Test Harness</title>

    <%-- AccordionGrid: single file, zero external dependencies --%>
    <script src="Scripts/AccordionGrid.js"></script>

    <style>
        * { box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background: #eef0ee;
            margin: 0;
            padding: 24px;
            font-size: 13px;
        }
        .page-wrap { max-width: 1400px; margin: 0 auto; }

        /* { } JSON chip inside the Extraction status column */
        .ag-json-chip {
            display: inline-block;
            margin-left: 6px;
            padding: 2px 7px;
            border: 1px solid #bcd9bc;
            border-radius: 10px;
            background: #f3faf3;
            color: #236122;
            font-family: Consolas, monospace;
            font-size: 10.5px;
            font-weight: 700;
            cursor: pointer;
            vertical-align: middle;
            white-space: nowrap;
        }
        .ag-json-chip:hover {
            background: #2e7d2e;
            border-color: #2e7d2e;
            color: #fff;
        }

        /* ── "section" chrome that mimics C3 ── */
        .c3-section {
            background: #fff;
            border: 1px solid #d0d4d0;
            border-radius: 6px;
            margin-bottom: 24px;
            overflow: hidden;
        }
        .c3-section-header {
            background: #f4f5f4;
            border-bottom: 1px solid #d0d4d0;
            padding: 9px 16px;
            font-size: 13px;
            font-weight: 600;
            color: #2e7d2e;
        }
        .c3-section-body { padding: 16px; }

        /* ── Debug panel ── */
        #debugPanel {
            background: #1a1a1a;
            color: #7ec87e;
            font-family: Consolas, monospace;
            font-size: 12px;
            padding: 12px 14px;
            border-radius: 4px;
            max-height: 180px;
            overflow-y: auto;
            margin-top: 16px;
            white-space: pre-wrap;
        }
        #debugPanel .info  { color: #87ceeb; }
        #debugPanel .warn  { color: #f0c040; }
        #debugPanel .err   { color: #f08080; }
        #debugPanel .ok    { color: #7ec87e; }

        .debug-toggle {
            font-size: 12px;
            color: #666;
            cursor: pointer;
            margin-top: 8px;
            display: inline-block;
            user-select: none;
        }
        .debug-toggle:hover { color: #2e7d2e; }
    </style>
</head>
<body>
<form id="form1" runat="server">

<%-- Hidden fields: code-behind writes JSON here. Always in the rendered HTML,
     no timing dependency on RegisterStartupScript injection order.
     Same belt-and-suspenders pattern used for both grid data and lookups. --%>
<asp:HiddenField ID="HiddenGridData"  runat="server" ClientIDMode="Static" Value="[]" />
<asp:HiddenField ID="HiddenLookups"   runat="server" ClientIDMode="Static" Value="{}" />
<div class="page-wrap">

    <%-- ── Page header ── --%>
    <div style="margin-bottom:18px;">
        <h1 style="font-size:18px;font-weight:600;color:#1a1e1a;margin:0 0 4px;">
            POA Form Management
        </h1>
        <p style="color:#6a736a;margin:0;font-size:12px;">
            Test harness — hardcoded service data, no database required.
        </p>
    </div>

    <%-- ── Grid section ── --%>
    <div class="c3-section">
        <div class="c3-section-header">+ Add / Edit POA Template</div>
        <div class="c3-section-body">
            <%-- AccordionGrid mounts here --%>
            <div id="poaGrid"></div>
        </div>
    </div>

    <%-- ── Debug panel (collapsible) ── --%>
    <span class="debug-toggle" onclick="toggleDebug()">▼ Event log</span>
    <div id="debugPanel"></div>

</div>
</form>

<%-- ═════════════════════════════════════════════════════════════════
     GRID INITIALISATION
     window.poaTemplatesData is injected by the code-behind via
     ClientScript.RegisterStartupScript (runs just before </form>).
═════════════════════════════════════════════════════════════════ --%>
<script type="text/javascript">
    (function () {
        'use strict';

        /* ── Columns shown in the collapsed row ───────────────────────
           WIDTH BUDGET: the row must fit inside .page-wrap. Fixed parts:
           expander 36 + State 70 + Extraction 150 (badge + JSON chip) +
           Mapping 100 + LastUpdated 140 + UpdatedBy 110 + Active 70 +
           Actions 400 = 1076px. Whatever remains goes to Description (flex).
           ⚠ Do NOT give Description a fixed width — it is the ONE
           elastic column that absorbs leftover space. Fixing it means
           no column can flex, and the slack becomes a dead gap before
           the Actions buttons. Users can still drag-resize it live.
        ──────────────────────────────────────────────────────────── */
        var columns = [
            { key: 'Description', label: 'Description', sortable: true },   // flexible — no width!
            { key: 'State', label: 'State', width: '70px', sortable: true, align: 'center' },
            {
                /* Badge + clickable { } JSON chip when Completed.
                   The chip (not a new action button) opens the extraction
                   viewer — handled by delegated click on .ag-json-chip. */
                key: 'ExtractionStatus', label: 'Extraction', width: '150px', sortable: true,
                format: function (v, r) {
                    var map = { 'Completed': 'success', 'In Progress': 'info',
                                'Not Started': 'default', 'Error': 'danger' };
                    var cls = map[v] || 'default';
                    var html = '<span class="ag-badge ag-badge-' + cls + '">' + v + '</span>';
                    if (v === 'Completed') {
                        html += '<span class="ag-json-chip" data-jsonid="' + r.Id + '"'
                              + ' title="View extraction JSON (structure + normalized)">'
                              + '{&hairsp;}&nbsp;JSON</span>';
                    }
                    return html;
                }
            },
            {
                key: 'MappingStatus', label: 'Mapping', width: '100px', sortable: true,
                badge: { map: { 'Mapped': 'success', 'Partial': 'info', 'Not Mapped': 'default' }, defaultClass: 'default' }
            },
            {
                key: 'LastUpdated', label: 'Last Updated', width: '140px', sortable: true,
                align: 'center',
                format: function (v) {
                    if (!v) return '<span style="color:#9aa09a;font-size:12px;">—</span>';
                    return '<span style="font-size:12px;">' + v + '</span>';
                }
            },
            {
                // Display name of the last editor. Stamped server-side on
                // Insert/Update — the grid._apply() re-fetch in onSave brings
                // the fresh value back automatically. Display-only column:
                // no editField key contract, no DTO field.
                key: 'UpdatedBy', label: 'Updated By', width: '110px', sortable: true,
                format: function (v) {
                    if (!v) return '<span style="color:#9aa09a;font-size:12px;">—</span>';
                    return '<span style="font-size:12px;">' + v + '</span>';
                }
            },
            {
                key: 'Active', label: 'Active', width: '70px', align: 'center',
                format: function (v) {
                    return v
                        ? '<span class="ag-badge ag-badge-success">Yes</span>'
                        : '<span class="ag-badge ag-badge-danger">No</span>';
                }
            }
        ];

        /* ── Lookup tables ────────────────────────────────────────────
           PRIMARY:   HiddenLookups hidden field — always in the rendered
                      HTML, no timing dependency on script injection order.
           SECONDARY: window.poaLookups — set by RegisterStartupScript,
                      used as fallback if the hidden field is empty.
        ──────────────────────────────────────────────────────────── */
        var LOOKUPS = null;

        // Primary: hidden field
        var hiddenLookups = document.getElementById('HiddenLookups');
        if (hiddenLookups && hiddenLookups.value && hiddenLookups.value !== '{}') {
            try {
                LOOKUPS = JSON.parse(hiddenLookups.value);
                log('ok', 'Lookups source: HiddenLookups field.');
            } catch (ex) {
                log('err', 'HiddenLookups parse error: ' + ex.message);
            }
        }

        // Secondary: window variable from RegisterStartupScript
        if (!LOOKUPS && window.poaLookups) {
            LOOKUPS = window.poaLookups;
            log('info', 'Lookups source: window.poaLookups.');
        }

        if (!LOOKUPS) {
            log('err', 'Lookups not found. Check LoadLookups() in code-behind — ' +
                'verify HiddenLookups.Value is assigned and RegisterStartupScript is executing.');
        }

        /* ── Edit fields shown in the expanded accordion panel ─────── */
        var editFields = [
            { key: 'Description', label: 'Description', type: 'text', required: true, placeholder: 'Enter description' },
            { key: 'State', label: 'State', type: 'select', options: LOOKUPS.states },
            { key: 'MailCenterId', label: 'Mail Center', type: 'select', options: LOOKUPS.mailCenters },
            { key: 'Active', label: 'Active', type: 'checkbox' },

            // Key names use the Id suffix so e.record stores the FK id directly
            // under the same name as the DTO field — no translation needed in onSave.
            { key: 'ServiceTypeId', label: 'Service Type', type: 'select', options: LOOKUPS.serviceTypes },
            { key: 'PoaFormTypeId', label: 'Form Type', type: 'select', options: LOOKUPS.poaFormTypes },
            { key: 'FormUseId', label: 'Form Use', type: 'select', options: LOOKUPS.formUses },
            { key: 'PoaTypeId', label: 'POA Type', type: 'select', options: LOOKUPS.poaTypes },

            { key: 'SignatureTypeId', label: 'Signature Type', type: 'select', options: LOOKUPS.signatureTypes },
            { key: 'ReturnTypeId', label: 'Return Type', type: 'select', options: LOOKUPS.returnTypes },
            { key: 'OnlineRequirementId', label: 'Online Requirement', type: 'select', options: LOOKUPS.onlineRequirements },

            { key: 'FileName', label: 'File Name', type: 'text', readOnly: true },
            { key: 'DocumentReference', label: 'Document Reference', type: 'text', readOnly: true },
            // Audit field — server-stamped, never user-editable (readOnly, not
            // disabled: disabled inputs are skipped by _collectFormValues).
            { key: 'UpdatedBy', label: 'Updated By', type: 'text', readOnly: true },
            { key: 'Notes', label: 'Notes', type: 'textarea', fullWidth: true, placeholder: 'Optional notes…' }
        ];

        /* ── Sections (green header groupings in the edit panel) ───── */
        var editSections = [
            { title: 'Template Info', fields: ['Description', 'State', 'MailCenterId', 'Active'] },
            { title: 'Classification', fields: ['ServiceTypeId', 'PoaFormTypeId', 'FormUseId', 'PoaTypeId'] },
            { title: 'Processing Rules', fields: ['SignatureTypeId', 'ReturnTypeId', 'OnlineRequirementId'] },
            { title: 'Document', fields: ['FileName', 'DocumentReference', 'UpdatedBy'], isDocumentSection: true },
            { title: 'Notes', fields: ['Notes'] }
        ];

        /* ── Action buttons in the Actions column ───────────────────── */
        var actionButtons = [
            { key: 'edit', label: 'Edit' },

            /* ── EXTRACTION BUTTON — one slot, three states ──────────────
                 Not Started / Error → "Extract"
                 In Progress         → "In Progress" (gray, unclickable)
                 Completed           → "Re-Extract" (enabled again)
               Viewing the JSON is NOT an action button — it's the { } JSON
               chip inside the Extraction status column (see columns config).
            ──────────────────────────────────────────────────────────── */
            {
                key: 'extract', label: 'Extract',
                // Visible even when no document is uploaded yet — hiding the
                // button made rows look broken. The CLICK validates instead:
                // startExtraction alerts "nothing to extract" client-side and
                // the server refuses too.
                visible: function (r) {
                    return r.ExtractionStatus !== 'In Progress' &&
                           r.ExtractionStatus !== 'Completed';
                }
            },
            {
                key: 'extracting', label: 'In Progress',
                disabled: true,
                disabledTitle: 'Extraction is running — please wait',
                visible: function (r) { return r.ExtractionStatus === 'In Progress'; }
            },
            {
                key: 'reextract', label: 'Re-Extract',
                visible: function (r) { return r.ExtractionStatus === 'Completed'; }
            },

            { key: 'map', label: 'Map' },
            {
                key: 'generate', label: 'Generate', cssClass: 'ag-btn-primary',
                visible: function (r) { return r.MappingStatus === 'Mapped'; }
            },
            {
                key: 'download', label: 'Download',
                visible: function (r) {
                    return !!(r.DocumentReference && r.DocumentReference.length > 0);
                }
            },
            { key: 'delete', label: 'Delete', cssClass: 'ag-btn-danger' }
        ];

        /* ── Filter dropdown (by State) ─────────────────────────────── */
        var filterOptions = [
            { label: 'All States', value: '' },
            { label: 'TX', value: 'TX' },
            { label: 'CA', value: 'CA' },
            { label: 'OH', value: 'OH' },
            { label: 'NY', value: 'NY' },
            { label: 'FL', value: 'FL' }
        ];

        /* ── Create the grid ─────────────────────────────────────────── */
        var grid = AccordionGrid.create('poaGrid', {
            title: 'POA Templates',
            addButtonLabel: '+ Add New Template',
            showAddButton: true,
            singleExpand: true,
            expandMode: 'edit',
            pageSize: 10,
            pageSizeOptions: [10, 25, 50],
            searchPlaceholder: 'Search templates…',
            filterField: 'State',
            filterOptions: filterOptions,
            emptyMessage: 'No templates found.',
            columns: columns,
            editFields: editFields,
            editSections: editSections,
            actionButtons: actionButtons,
            showInsert: true,
            showUpdate: true,
            showDelete: true,
            showCancel: true,

            /* ── Column layout ───────────────────────────────────────
               resizableColumns: drag the right edge of any column
               header to resize (Excel-style); double-click the handle
               to reset that column. Defaults stay aligned regardless
               of text length or button count per row.
               actionsColumnWidth: FIXED width, sized SNUG to the
               fullest button row INCLUDING Generate
               (Edit+Extract+Map+Generate+Download+Delete).
               Snug = no dead gap between data columns and buttons.
               Re-measure if buttons are added/removed.
            ────────────────────────────────────────────────────────*/
            resizableColumns: true,
            actionsColumnWidth: '400px',

            /* ── SERVER-SIDE PAGINATION via dataLoader ───────────────
               The grid calls this every time the user pages, searches,
               sorts, or changes the filter.  params contains:
                 { page, pageSize, search, filter, sortKey, sortDir }
               done(array) hands the page slice back to the grid.
               The grid uses _serverTotalCount (set below on first load)
               for the pager — it never tries to count client-side.
            ────────────────────────────────────────────────────────*/
            dataLoader: function (params, done) {
                log('info', 'dataLoader → page=' + params.page +
                    ' size=' + params.pageSize +
                    (params.search ? ' search="' + params.search + '"' : '') +
                    (params.filter ? ' filter="' + params.filter + '"' : '') +
                    (params.sortKey ? ' sort=' + params.sortKey + ' ' + params.sortDir : ''));

                fetch('Default.aspx/GetPage', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=utf-8',
                        'X-Requested-With': 'XMLHttpRequest'
                    },
                    body: JSON.stringify({
                        page: params.page,
                        pageSize: params.pageSize,
                        search: params.search || '',
                        filter: params.filter || '',
                        sortKey: params.sortKey || '',
                        sortDir: params.sortDir || 'asc'
                    }),
                    credentials: 'same-origin'
                })
                    .then(function (r) {
                        if (!r.ok) throw new Error('HTTP ' + r.status);
                        return r.json();
                    })
                    .then(function (resp) {
                        // WebMethod wraps in { d: "json-string" }
                        var payload = typeof resp.d === 'string'
                            ? JSON.parse(resp.d) : resp;

                        // Update the pager total any time the server reports a new count
                        // (search/filter may reduce it)
                        grid._serverTotalCount = payload.totalCount;
                        grid._filtered = { length: payload.totalCount }; // tells pager the real total
                        log('ok', 'dataLoader ← ' + payload.items.length +
                            ' items, total=' + payload.totalCount);
                        done(payload.items);
                    })
                    .catch(function (err) {
                        log('err', 'dataLoader failed: ' + err.message);
                        done([]);
                    });
            },

            /* ── PDF / blob upload ──────────────────────────────────
               Called by the grid when user clicks "Upload to Storage".
               Receives: file (File object), onProgress(pct), done(err, guid)
               In production: POST to UploadDocument WebMethod.
            ────────────────────────────────────────────────────────*/
            uploadDocumentField: 'DocumentReference',   // GUID stored here
            uploadMaxSizeMb: 20,                   // 15 | 20 | 30 — default 20
            uploadAllowedExtensions: ['.pdf'],          // e.g. ['.pdf','.docx','.tiff']
            onUploadDocument: function (file, onProgress, done) {
                log('info', 'Upload started: ' + file.name + ' (' + (file.size / 1024).toFixed(1) + ' KB)');

                // POST to the Generic Handler (.ashx) — NOT a [WebMethod].
                // [WebMethod] requires Content-Type: application/json and cannot
                // receive multipart/form-data; the .ashx handles all request types.
                var form = new FormData();
                form.append('file', file, file.name);   // key "file" must match
                // Request.Files["file"] in the handler

                // XHR instead of fetch() — only XHR exposes upload progress events.
                var xhr = new XMLHttpRequest();

                xhr.upload.addEventListener('progress', function (e) {
                    if (e.lengthComputable) {
                        onProgress(Math.round((e.loaded / e.total) * 100));
                    }
                });

                xhr.addEventListener('load', function () {
                    try {
                        var resp = JSON.parse(xhr.responseText);
                        if (xhr.status === 200 && resp.guid) {
                            log('ok', 'Upload complete. Reference: ' + resp.guid);
                            done(null, resp.guid);
                        } else {
                            // Handler returned { "error": "..." }
                            var msg = (resp && resp.error) ? resp.error : 'Upload failed (HTTP ' + xhr.status + ').';
                            log('err', msg);
                            done(msg);
                        }
                    } catch (ex) {
                        // Response was not JSON — likely an unhandled server error page
                        var raw = xhr.responseText ? xhr.responseText.substring(0, 120) : '(empty)';
                        log('err', 'Non-JSON response: ' + raw);
                        done('Unexpected response from server. Check the browser Network tab for details.');
                    }
                });

                xhr.addEventListener('error', function () {
                    var msg = 'Network error during upload.';
                    log('err', msg);
                    done(msg);
                });

                xhr.open('POST', 'UploadDocument.ashx');
                xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
                xhr.send(form);
            },

            /* ── Callbacks ─────────────────────────────────────────── */
            onLoad: function (e) {
                log('ok', 'Grid loaded — ' + e.data.length + ' records.');
            },

            onSave: function (e) {
                // Build a clean payload containing only the fields PoaFormDto
                // expects.  e.record also contains internal grid keys (_agId,
                // ExtractionStatus, etc.) that would cause a 500 if sent raw.
                // Active comes from a checkbox so coerce to bool explicitly.
                var dto = {
                    Id: e.record.Id || 0,
                    Description: e.record.Description || '',
                    State: e.record.State || '',   // code (TX, CA…) → StateId on server
                    Active: e.record.Active === true || e.record.Active === 'true' || e.record.Active === 'on',
                    MailCenterId: parseInt(e.record.MailCenterId, 10) || null,

                    // Select fields: key name matches DTO field name directly.
                    // e.record.ServiceTypeId already holds the FK int — no translation.
                    ServiceTypeId: parseInt(e.record.ServiceTypeId, 10) || null,
                    PoaFormTypeId: parseInt(e.record.PoaFormTypeId, 10) || null,
                    FormUseId: parseInt(e.record.FormUseId, 10) || null,
                    PoaTypeId: parseInt(e.record.PoaTypeId, 10) || null,
                    SignatureTypeId: parseInt(e.record.SignatureTypeId, 10) || null,
                    ReturnTypeId: parseInt(e.record.ReturnTypeId, 10) || null,
                    OnlineRequirementId: parseInt(e.record.OnlineRequirementId, 10) || null,

                    DocumentReference: e.record.DocumentReference || '',
                    FileName: e.record.FileName || '',
                    FileExtension: e.record.FileExtension || '',
                    Notes: e.record.Notes || ''
                };

                if (e.isNew) {
                    // ── INSERT ────────────────────────────────────────────────
                    // ASP.NET WebMethod with a DTO parameter requires the body
                    // wrapped as { "form": { ... } } matching the param name.
                    // After the server confirms, re-fetch the current page from
                    // the server (grid._apply keeps page/search/filter/sort) so
                    // the row shows the true Id, LastUpdated and UpdatedBy.
                    callPageMethod('InsertForm', { form: dto }, function (resp) {
                        log('ok', 'INSERT confirmed — newId=' + resp.Id
                            + '  updated=' + resp.LastUpdated
                            + '  by=' + resp.UpdatedBy);
                        grid._apply();
                    });
                } else {
                    // ── UPDATE ────────────────────────────────────────────────
                    callPageMethod('UpdateForm', { form: dto }, function (resp) {
                        log('ok', 'UPDATE confirmed — id=' + e.record.Id
                            + '  updated=' + resp.LastUpdated
                            + '  by=' + resp.UpdatedBy);
                        grid._apply();
                    });
                }
            },

            onDelete: function (e) {
                // Fired by the form Cancel/Delete button inside the expanded panel.
                // The action-button Delete path is handled in onActionClick below.
                log('warn', 'onDelete fired — id=' + e.record.Id);
            },

            onActionClick: function (e) {
                switch (e.action) {

                    // ── EDIT ──────────────────────────────────────────────────
                    case 'edit':
                        // Expands the row in full edit mode (all fields editable).
                        // The ▶ arrow expands in read-only view mode instead.
                        grid.expandRowForEdit(e.id);
                        break;

                    // ── EXTRACT ───────────────────────────────────────────────
                    // 1. POST to TriggerExtraction  → sets status "In Progress",
                    //    enqueues Hangfire job, returns JobId.
                    // 2. Badge flips to "In Progress" immediately.
                    // 3. Poll GetExtractionStatus every 5 s until Completed/Error.
                    // 4. Badge flips to final status and polling stops.
                    // ── EXTRACT / RE-EXTRACT ──────────────────────────────────
                    // Three guards, cheapest first:
                    //   1. button visibility (status-driven, above)
                    //   2. in-flight lock — blocks the double-click race in
                    //      the window before the server answers
                    //   3. server validation — the actual authority
                    case 'extract':
                        startExtraction(e.id, e.record, false);
                        break;

                    case 'reextract':
                        // Re-extraction replaces the extracted structure. If a
                        // mapping was already published against the old field
                        // keys, it may no longer line up — make that explicit.
                        var warn = 'Re-extract this template?\n\n'
                                 + 'The current extracted structure will be replaced.';
                        if (e.record.MappingStatus === 'Mapped'
                            || e.record.MappingStatus === 'Partial') {
                            warn += '\n\nThis template already has a mapping ('
                                  + e.record.MappingStatus + '). If the detected '
                                  + 'fields change, the mapping will need to be '
                                  + 'reviewed and re-published.';
                        }
                        if (!confirm(warn)) {
                            log('info', 'Re-extraction cancelled — id=' + e.record.Id);
                            break;
                        }
                        startExtraction(e.id, e.record, true);
                        break;

                    // Disabled placeholder — a disabled button fires no click,
                    // so this only runs if something else dispatches the action.
                    case 'extracting':
                        log('warn', 'Extraction already running — id=' + e.record.Id);
                        break;

                    // (JSON viewing moved to the { } JSON chip in the
                    // Extraction column — no dedicated action button.)

                    // ── MAP ───────────────────────────────────────────────────
                    // Opens the Mapping Summary modal (prototype screen 5):
                    // per-field Mapped/Manual/Ignored + C3 data source target,
                    // Validate → Save Draft (Partial) / Publish (Mapped).
                    // The grid stays a router: mapping lives in PoaMapping,
                    // the grid only launches it and receives the badge update.
                    // Production designer (screen 4, PDF overlay) will replace
                    // the modal body — same WebMethod contract.
                    case 'map':
                        if (e.record.ExtractionStatus !== 'Completed') {
                            log('warn', 'Map blocked — extraction is "' +
                                e.record.ExtractionStatus + '" (needs Completed).');
                            alert('Run Extract first — mapping needs a completed extraction.');
                            break;
                        }
                        PoaMapping.open(e.id, e.record, grid, log);
                        break;

                    // ── GENERATE ─────────────────────────────────────────────
                    // Calls GenerateDocument which triggers the merge pipeline.
                    // In production: navigate to the generated document URL.
                    case 'generate':
                        callPageMethod('GenerateDocument', { Id: e.record.Id },
                            function (resp) {
                                log('ok', 'Generate confirmed — id=' + e.record.Id);
                                // In production, navigate to the output:
                                // if (resp.RedirectUrl) window.location.href = resp.RedirectUrl;
                                alert('Document generated for: ' + e.record.Description);
                            });
                        break;

                    // ── DOWNLOAD ─────────────────────────────────────────────
                    // Fetches the blob from DownloadDocument.ashx (mirrors
                    // GetXMFaxReceipt: blobName → stream → file attachment).
                    case 'download':
                        if (e.record.DocumentReference) {
                            var url = 'DownloadDocument.ashx' +
                                '?blobName=' + encodeURIComponent(e.record.DocumentReference) +
                                '&fileName=' + encodeURIComponent(e.record.FileName || e.record.DocumentReference) +
                                '&fileExt=' + encodeURIComponent(e.record.FileExtension || '.pdf');
                            log('info', 'Download → ' + url);
                            // Hidden iframe: triggers browser save dialog without
                            // navigating away from the page.
                            var dlFrame = document.getElementById('ag-dl-frame');
                            if (!dlFrame) {
                                dlFrame = document.createElement('iframe');
                                dlFrame.id = 'ag-dl-frame';
                                dlFrame.style.display = 'none';
                                document.body.appendChild(dlFrame);
                            }
                            dlFrame.src = url;
                        }
                        break;

                    // ── DELETE ────────────────────────────────────────────────
                    // Confirms with the user, calls DeleteForm WebMethod, then
                    // removes the row from the grid only after server confirms.
                    case 'delete':
                        if (confirm('Delete "' + e.record.Description + '"?')) {
                            callPageMethod('DeleteForm', { Id: e.record.Id },
                                function (resp) {
                                    if (resp && resp.Success) {
                                        grid.removeRecord(e.id);
                                        log('warn', 'DELETE confirmed — id=' + e.record.Id
                                            + ' "' + e.record.Description + '"');
                                    } else {
                                        log('err', 'DELETE failed — id=' + e.record.Id);
                                    }
                                });
                        }
                        break;
                }
            },

            onSearch: function (e) { log('info', 'Search: "' + e.value + '"'); },
            onFilterChange: function (e) { log('info', 'Filter: "' + (e.value || 'All') + '"'); },
            onSort: function (e) { log('info', 'Sort: ' + e.key + ' ' + e.dir); },
            onPageChange: function (e) { log('info', 'Page: ' + e.page); }
        });

        /* ── Extraction polling ───────────────────────────────────────
           After TriggerExtraction succeeds, poll GetExtractionStatus
           every 5 seconds until the job reaches Completed or Error.
           The badge updates in real time with each status response.
        ──────────────────────────────────────────────────────────── */
        /* ── In-flight lock ───────────────────────────────────────────
           Button visibility already hides Extract while In Progress, but
           between the click and the server's answer the row still shows the
           old status — a fast double-click would fire two requests. This
           lock closes that window client-side; the server closes it for
           real (stale pages, other tabs, crafted posts).
        ──────────────────────────────────────────────────────────── */
        var extractionInFlight = {};

        function startExtraction(agId, record, force) {
            var formId = record.Id;

            if (extractionInFlight[formId]) {
                log('warn', 'Extraction request already in flight — id=' + formId);
                return;
            }
            if (record.ExtractionStatus === 'In Progress') {
                log('warn', 'Extraction already running — id=' + formId);
                return;
            }
            if (!record.DocumentReference) {
                alert('No document uploaded for this template — nothing to extract.');
                return;
            }

            extractionInFlight[formId] = true;

            callPageMethod('TriggerExtraction', { Id: formId, force: !!force },
                function (resp) {
                    // Server rejected it (already running, already extracted,
                    // no document, not found) — surface the reason and
                    // realign the badge with whatever the server reports.
                    if (resp.Error) {
                        delete extractionInFlight[formId];
                        log('err', 'Extraction refused — id=' + formId + ' — ' + resp.Error);
                        alert(resp.Error);
                        if (resp.Status) grid.updateRecord(agId, { ExtractionStatus: resp.Status });
                        return;
                    }

                    grid.updateRecord(agId, { ExtractionStatus: resp.Status });
                    log('info', (resp.IsReextraction ? 'RE-extraction' : 'Extraction')
                        + ' queued — id=' + formId + '  jobId=' + resp.JobId);
                    startExtractionPolling(agId, formId, resp.JobId);
                },
                function () {                       // transport failure
                    delete extractionInFlight[formId];
                    log('err', 'Extraction request failed — id=' + formId);
                });
        }

        function startExtractionPolling(agId, formId, jobId) {
            var MAX_POLLS = 24;   // 24 × 5s = 2 minutes max before giving up
            var polls = 0;

            var timer = setInterval(function () {
                polls++;
                callPageMethod('GetExtractionStatus', { Id: formId },
                    function (resp) {
                        log('info', 'Poll #' + polls + ' — id=' + formId
                            + '  status=' + resp.Status
                            + (jobId ? '  job=' + jobId : ''));

                        grid.updateRecord(agId, { ExtractionStatus: resp.Status });

                        if (resp.Status === 'Completed' || resp.Status === 'Error') {
                            clearInterval(timer);
                            delete extractionInFlight[formId];   // release the lock
                            log(resp.Status === 'Completed' ? 'ok' : 'err',
                                'Extraction ' + resp.Status + ' — id=' + formId);
                        } else if (polls >= MAX_POLLS) {
                            clearInterval(timer);
                            delete extractionInFlight[formId];
                            log('warn', 'Extraction polling timed out — id=' + formId
                                + ' (job may still be running; Refresh to re-check)');
                        }
                    });
            }, 5000);   // poll every 5 seconds
        }

        /* ── Generic WebMethod caller ─────────────────────────────────
           POSTs JSON to Default.aspx/<method>, unwraps ASP.NET's
           { d: "json-string" } wrapper, parses the inner JSON, and
           calls onSuccess(parsedResult).
        ──────────────────────────────────────────────────────────── */
        function callPageMethod(method, payload, onSuccess, onError) {
            fetch(window.location.href.split('?')[0] + '/' + method, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=utf-8',
                    'X-Requested-With': 'XMLHttpRequest'
                },
                body: JSON.stringify(payload),
                credentials: 'same-origin'
            })
                .then(function (r) {
                    if (!r.ok) throw new Error('HTTP ' + r.status);
                    return r.json();
                })
                .then(function (resp) {
                    // WebMethods return { "d": "json-string" } — parse the inner value
                    var inner = (resp && resp.d !== undefined) ? resp.d : resp;
                    if (typeof inner === 'string') {
                        try { inner = JSON.parse(inner); } catch (e) { /* scalar value */ }
                    }
                    if (onSuccess) onSuccess(inner);
                })
                .catch(function (err) {
                    log('err', method + ' failed: ' + err.message);
                    // Let the caller undo optimistic UI / release locks.
                    if (onError) onError(err);
                });
        }

        /* ── Shared transport for page modules ────────────────────────
           PoaExtractionViewer and PoaMapping live outside this closure.
           They MUST use this exact caller — it is the transport that
           demonstrably works in this environment (headers, credentials,
           { d } unwrapping). Their own raw fetch was the cause of
           "Failed to fetch" while the grid loaded fine.
        ──────────────────────────────────────────────────────────── */
        window.poaCallPageMethod = callPageMethod;

        /* ── Load initial data ────────────────────────────────────────
           poaInitialData is { items:[...], totalCount:N, pageSize:N, page:1 }
           set by RegisterStartupScript / HiddenField on Page_Load.
           This is the FIRST page only — every subsequent page goes
           through dataLoader → GetPage WebMethod.
        ──────────────────────────────────────────────────────────── */
        var initial = null;

        // Primary: hidden field (always rendered, no timing dependency)
        var hiddenEl = document.getElementById('HiddenGridData');
        if (hiddenEl && hiddenEl.value && hiddenEl.value !== '[]' && hiddenEl.value !== '') {
            try { initial = JSON.parse(hiddenEl.value); }
            catch (ex) { log('err', 'HiddenField parse error: ' + ex.message); }
        }
        // Secondary: window variable from RegisterStartupScript
        if (!initial && window.poaInitialData) {
            initial = window.poaInitialData;
        }

        if (initial && initial.items && initial.items.length) {
            // Tell the grid the TRUE total so the pager shows correct page count
            // even though we only handed it the first page slice.
            grid._serverTotalCount = initial.totalCount;

            log('ok', 'Initial load — ' + initial.items.length +
                ' items on page 1 of ' +
                Math.ceil(initial.totalCount / initial.pageSize) +
                ' (total: ' + initial.totalCount + ').');

            grid.loadData(initial.items);

        /* ── { } JSON chip → extraction viewer ────────────────────────
           Delegated on the grid container: rows re-render constantly,
           so per-chip listeners would be lost. stopPropagation keeps
           the click from toggling anything else in the row. ─────────── */
        document.getElementById('poaGrid').addEventListener('click', function (e) {
            var chip = e.target.closest ? e.target.closest('.ag-json-chip') : null;
            if (!chip) return;
            e.stopPropagation();
            var id = parseInt(chip.getAttribute('data-jsonid'), 10);
            var rec = null;
            (grid._allData || []).forEach(function (r) { if (r.Id === id) rec = r; });
            if (rec) PoaExtractionViewer.open(rec, log);
        });

            // Patch the pager total after loadData (loadData resets _filtered)
            grid._filtered = { length: initial.totalCount };
            grid._renderPager && grid._renderPager();
        } else {
            log('err', 'No initial data — check LoadFirstPage() in code-behind.');
        }

        /* ── Debug log helpers ───────────────────────────────────── */
        function log(level, msg) {
            var panel = document.getElementById('debugPanel');
            var line = document.createElement('div');
            var ts = new Date().toLocaleTimeString();
            line.className = level;
            line.textContent = '[' + ts + '] ' + msg;
            panel.appendChild(line);
            panel.scrollTop = panel.scrollHeight;
            console[level === 'err' ? 'error' : level === 'warn' ? 'warn' : 'log'](msg);
        }

    }());

    function toggleDebug() {
        var p = document.getElementById('debugPanel');
        p.style.display = p.style.display === 'none' ? 'block' : 'none';
    }
</script>

<!-- ═══════════════════════════════════════════════════════════════════════
     EXTRACTION OUTPUT VIEWER (prototype screen 3 — "Extraction Result")
     Read-only view of the normalized TemplateStructure the engine produced:
     detected fields tab + raw JSON tab, with copy / download.
     ═══════════════════════════════════════════════════════════════════════ -->
<style>
    .px-overlay { display: none; position: fixed; inset: 0; z-index: 4100;
                  background: rgba(20,24,20,.55); }
    .px-modal {
        position: absolute; top: 4%; left: 50%; transform: translateX(-50%);
        width: 1100px; max-width: 96vw; max-height: 92vh; background: #fff;
        border-radius: 10px; box-shadow: 0 18px 60px rgba(0,0,0,.35);
        display: flex; flex-direction: column;
        font-family: 'Segoe UI', Arial, sans-serif;
    }
    .px-head { padding: 14px 20px; border-bottom: 1px solid #e2e6e2;
               display: flex; align-items: center; gap: 14px; }
    .px-head h2 { margin: 0; font-size: 17px; color: #1a1e1a; }
    .px-sub { color: #7a837a; font-size: 12.5px; }
    .px-close { margin-left: auto; border: none; background: none; font-size: 22px;
                color: #7a837a; cursor: pointer; line-height: 1; }
    .px-close:hover { color: #1a1e1a; }
    .px-chips { display: flex; gap: 10px; padding: 12px 20px 4px; }
    .px-chip { flex: 1; border: 1px solid #e2e6e2; border-radius: 8px;
               padding: 8px 12px; text-align: center; }
    .px-chip b { display: block; font-size: 19px; color: #1a1e1a; }
    .px-chip span { font-size: 11.5px; color: #7a837a; }
    .px-chip.review { background: #fff8e1; border-color: #e4d091; }
    .px-chip.review b { color: #9c7a00; }
    .px-tabs { display: flex; gap: 6px; padding: 10px 20px 0; border-bottom: 1px solid #e2e6e2; }
    .px-tab { padding: 7px 16px; border: 1px solid #d4d8db; border-bottom: none;
              border-radius: 6px 6px 0 0; background: #f4f5f6; cursor: pointer;
              font-size: 12.5px; color: #4a5048; }
    .px-tab.active { background: #fff; color: #236122; font-weight: 600;
                     border-color: #bcd9bc; margin-bottom: -1px; }
    .px-body { padding: 12px 20px; overflow: auto; flex: 1; }
    .px-table { width: 100%; border-collapse: collapse; font-size: 12.5px; }
    .px-table th { text-align: left; padding: 7px 8px; background: #2e7d2e; color: #fff;
                   font-size: 11.5px; position: sticky; top: 0; }
    .px-table td { padding: 6px 8px; border-bottom: 1px solid #eef0ee; }
    .px-table tr:hover td { background: #f8faf8; }
    .px-key { font-weight: 600; color: #1a1e1a; }
    .px-label { color: #7a837a; font-size: 11.5px; }
    .px-rect { font-family: Consolas, monospace; font-size: 11.5px; color: #4a5048; }
    .px-flag { display: inline-block; padding: 2px 8px; border-radius: 10px;
               font-size: 11px; font-weight: 600; background: #fff8e1; color: #9c7a00; }
    .px-low { color: #c0392b; font-weight: 600; }
    .px-json { background: #1e2320; color: #d6e0d6; padding: 14px; border-radius: 8px;
               font-family: Consolas, monospace; font-size: 12px; line-height: 1.5;
               white-space: pre; overflow: auto; margin: 0; }
    .px-warn { margin: 8px 20px 0; padding: 9px 14px; background: #fff8e1;
               border: 1px solid #e4d091; border-radius: 8px; color: #7c5e00;
               font-size: 12.5px; }
    .px-foot { padding: 12px 20px; border-top: 1px solid #e2e6e2; display: flex; gap: 10px; }
    .px-btn { padding: 8px 18px; border-radius: 6px; font-size: 13px; cursor: pointer;
              border: 1px solid #cfd4cf; background: #fff; color: #1a1e1a; }
    .px-btn:hover { background: #f4f5f6; }
    .px-btn.primary { background: #2e7d2e; border-color: #2e7d2e; color: #fff; }
    .px-spacer { flex: 1; }
    .px-loading { padding: 40px; text-align: center; color: #7a837a; }
    .px-statusbar { display: flex; align-items: center; gap: 10px;
                    padding: 10px 20px; border-bottom: 1px solid #eef0ee;
                    font-size: 12.5px; color: #4a5048; }
    .px-status-ok { color: #2e7d2e; font-weight: 700; }
    .px-status-label { color: #7a837a; }
    .px-status-chip { padding: 2px 10px; border-radius: 10px; background: #eef7ee;
                      color: #2e7d2e; font-weight: 600; font-size: 11.5px; }
    .px-status-sep { color: #d4d8db; }
    .px-main { display: flex; gap: 0; flex: 1; min-height: 0; }
    .px-left { flex: 1; display: flex; flex-direction: column; min-width: 0; }
    .px-side { width: 300px; border-left: 1px solid #eef0ee; padding: 12px 16px;
               overflow: auto; background: #fbfcfb; }
    .px-panel { border: 1px solid #e8ece8; border-radius: 8px; background: #fff;
                padding: 12px 14px; margin-bottom: 12px; }
    .px-panel-title { font-size: 12.5px; font-weight: 700; color: #1a1e1a;
                      margin-bottom: 8px; }
    .px-stat { display: flex; justify-content: space-between; align-items: center;
               padding: 5px 0; font-size: 12.5px; color: #4a5048;
               border-bottom: 1px solid #f2f4f2; }
    .px-stat:last-child { border-bottom: none; }
    .px-stat b { background: #eef2ee; border-radius: 10px; padding: 1px 10px;
                 font-size: 12px; color: #1a1e1a; }
    .px-stat b.px-amber { background: #fff8e1; color: #9c7a00; }
    .px-src { padding: 4px 0; font-size: 12px; color: #4a5048; }
    .px-src span { color: #7a837a; display: block; font-size: 11px; }
    .px-mono { font-family: Consolas, monospace; font-size: 11px; word-break: break-all; }
</style>

<div class="px-overlay" id="pxOverlay">
    <div class="px-modal" role="dialog" aria-modal="true" aria-label="Normalized Extraction JSON">
        <div class="px-head">
            <h2>Normalized Extraction JSON</h2>
            <span class="px-sub" id="pxFormInfo"></span>
            <button type="button" class="px-close" id="pxClose" title="Close">&times;</button>
        </div>

        <!-- Status bar: Status chip · Started · Completed · Duration -->
        <div class="px-statusbar">
            <span class="px-status-ok">&#10003;</span>
            <span class="px-status-label">Status:</span>
            <span class="px-status-chip" id="pxRunStatus">Completed</span>
            <span class="px-status-sep">|</span>
            <span id="pxRunStarted"></span>
            <span class="px-status-sep">|</span>
            <span id="pxRunCompleted"></span>
            <span class="px-status-sep">|</span>
            <span id="pxRunDuration"></span>
        </div>

        <div class="px-warn" id="pxWarnings" style="display:none;"></div>

        <div class="px-main">
            <!-- LEFT: tabs + content -->
            <div class="px-left">
                <div class="px-tabs">
                    <div class="px-tab active" id="pxTabJson">Normalized JSON</div>
                    <div class="px-tab" id="pxTabFields">Detected fields</div>
                </div>
                <div class="px-body" id="pxBody">
                    <div class="px-loading">Loading extraction output…</div>
                </div>
            </div>

            <!-- RIGHT: summary + source document -->
            <div class="px-side">
                <div class="px-panel">
                    <div class="px-panel-title">Extraction Summary</div>
                    <div class="px-stat"><span>Total Fields</span><b id="pxCntFields">0</b></div>
                    <div class="px-stat"><span>Need Review</span><b class="px-amber" id="pxCntReview">0</b></div>
                    <div class="px-stat"><span>Signature Areas</span><b id="pxCntSig">0</b></div>
                    <div class="px-stat"><span>Pages</span><b id="pxCntPages">0</b></div>
                    <div class="px-stat"><span>Profile / Engine</span><b id="pxProfile">—</b></div>
                </div>
                <div class="px-panel">
                    <div class="px-panel-title">Source Document</div>
                    <div class="px-src"><span>File Name:</span><div id="pxSrcName">—</div></div>
                    <div class="px-src"><span>Reference:</span><div id="pxSrcRef" class="px-mono">—</div></div>
                    <div class="px-src"><span>Size:</span><div id="pxSrcSize">—</div></div>
                </div>
            </div>
        </div>

        <div class="px-foot">
            <button type="button" class="px-btn" id="pxCopy">&#128203; Copy to Clipboard</button>
            <span class="px-spacer"></span>
            <button type="button" class="px-btn" id="pxDownload">&#8681; Download JSON</button>
            <button type="button" class="px-btn primary" id="pxDone">Close</button>
        </div>
    </div>
</div>

<script>
/* ═══════════════════════════════════════════════════════════════════════════
   PoaExtractionViewer — read-only view of the normalized structure.
   Same pattern as PoaMapping: a page module, no AccordionGrid changes.
   ═══════════════════════════════════════════════════════════════════════ */
var PoaExtractionViewer = (function () {
    'use strict';

    var state = { structure: null, form: null, tab: 'fields', log: function () {} };

    function esc(s) {
        var d = document.createElement('div');
        d.textContent = s == null ? '' : String(s);
        return d.innerHTML;
    }

    function open(record, log) {
        state.log = log || function () {};
        state.tab = 'json';   // screenshot default: the JSON pane
        document.getElementById('pxFormInfo').textContent =
            record.Description + '  ·  ' + record.State;
        document.getElementById('pxBody').innerHTML =
            '<div class="px-loading">Loading extraction output…</div>';
        document.getElementById('pxWarnings').style.display = 'none';
        document.getElementById('pxOverlay').style.display = 'block';
        renderRunInfo(null, null);   // dashes until the data arrives
        setTab('json');

        // Uses the page's shared transport (window.poaCallPageMethod) —
        // the SAME caller the grid uses for every working request. The
        // viewer's previous private fetch was rejected in some setups
        // ("Failed to fetch") while grid calls succeeded.
        window.poaCallPageMethod('GetExtractionStructure', { Id: record.Id },
            function (inner) {
                if (inner && inner.Error) {
                    document.getElementById('pxBody').innerHTML =
                        '<div class="px-loading">' + esc(inner.Error) + '</div>';
                    state.log('warn', '[Extraction] ' + inner.Error);
                    return;
                }
                state.structure = inner.Structure;
                state.form = inner.Form;
                renderChips();
                renderRunInfo(inner.Run, inner.Source);
                render();
                state.log('info', '[Extraction] Viewed structure — id=' + record.Id
                    + '  fields=' + (state.structure.Fields || []).length);
            },
            function (err) {
                document.getElementById('pxBody').innerHTML =
                    '<div class="px-loading">Failed to load: '
                    + esc(err && err.message ? err.message : 'request error') + '</div>';
            });
    }

    function close() { document.getElementById('pxOverlay').style.display = 'none'; }

    function renderRunInfo(run, src) {
        run = run || {}; src = src || {};
        document.getElementById('pxRunStatus').textContent = run.Status || 'Completed';
        document.getElementById('pxRunStarted').textContent =
            'Started: ' + (run.Started || '—');
        document.getElementById('pxRunCompleted').textContent =
            'Completed: ' + (run.Completed || '—');
        document.getElementById('pxRunDuration').textContent =
            'Duration: ' + (run.Duration || '—');
        document.getElementById('pxSrcName').textContent = src.FileName || '—';
        document.getElementById('pxSrcRef').textContent = src.Reference || '—';
        document.getElementById('pxSrcSize').textContent = src.Size || '—';
    }

    function renderChips() {
        var s = state.structure;
        var fields = s.Fields || [];
        var review = fields.filter(function (f) { return f.NeedsReview; }).length;
        document.getElementById('pxCntFields').textContent = fields.length;
        document.getElementById('pxCntReview').textContent = review;
        document.getElementById('pxCntSig').textContent = (s.SignatureAreas || []).length;
        document.getElementById('pxCntPages').textContent = (s.Pages || []).length;
        document.getElementById('pxProfile').textContent = s.ProfileName + ' / v' + s.EngineVersion;

        var warnBox = document.getElementById('pxWarnings');
        if (s.Warnings && s.Warnings.length) {
            warnBox.innerHTML = s.Warnings.map(function (w) {
                return '• ' + esc(w);
            }).join('<br>');
            warnBox.style.display = 'block';
        } else {
            warnBox.style.display = 'none';
        }
    }

    function setTab(tab) {
        state.tab = tab;
        document.getElementById('pxTabFields').classList.toggle('active', tab === 'fields');
        document.getElementById('pxTabJson').classList.toggle('active', tab === 'json');
        if (state.structure) render();
    }

    function render() {
        var body = document.getElementById('pxBody');

        if (state.tab === 'json') {
            body.innerHTML = '<pre class="px-json">'
                + esc(JSON.stringify(state.structure, null, 2)) + '</pre>';
            return;
        }

        var fields = state.structure.Fields || [];
        var html = '<table class="px-table"><thead><tr>' +
            '<th style="width:190px;">Field</th>' +
            '<th style="width:90px;">Type</th>' +
            '<th style="width:40px;">Pg</th>' +
            '<th style="width:200px;">Position (page-relative)</th>' +
            '<th style="width:150px;">Detected by</th>' +
            '<th style="width:60px;">Conf</th>' +
            '<th style="width:90px;">Review</th>' +
            '</tr></thead><tbody>';

        fields.forEach(function (f) {
            var r = f.Rect || { X: 0, Y: 0, W: 0, H: 0 };
            html += '<tr>' +
                '<td><div class="px-key">' + esc(f.Key) + '</div>' +
                    '<div class="px-label">' + esc(f.Label) + '</div></td>' +
                '<td>' + esc(f.Type) + '</td>' +
                '<td>' + f.Page + '</td>' +
                '<td class="px-rect">x ' + r.X.toFixed(3) + '  y ' + r.Y.toFixed(3) +
                    '<br>w ' + r.W.toFixed(3) + '  h ' + r.H.toFixed(3) + '</td>' +
                '<td>' + esc(f.Source) + '</td>' +
                '<td' + (f.Confidence < 0.6 ? ' class="px-low"' : '') + '>' +
                    (f.Confidence * 100).toFixed(0) + '%</td>' +
                '<td>' + (f.NeedsReview ? '<span class="px-flag">REVIEW</span>' : '') + '</td>' +
                '</tr>';
        });

        html += '</tbody></table>';
        body.innerHTML = html;
    }

    function bindOnce() {
        document.getElementById('pxClose').addEventListener('click', close);
        document.getElementById('pxDone').addEventListener('click', close);
        document.getElementById('pxOverlay').addEventListener('click', function (e) {
            if (e.target === this) close();
        });
        document.getElementById('pxTabFields').addEventListener('click', function () { setTab('fields'); });
        document.getElementById('pxTabJson').addEventListener('click', function () { setTab('json'); });

        document.getElementById('pxCopy').addEventListener('click', function () {
            if (!state.structure) return;
            var text = JSON.stringify(state.structure, null, 2);
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text).then(function () {
                    alert('Extraction JSON copied to clipboard.');
                });
            } else {
                var ta = document.createElement('textarea');
                ta.value = text; document.body.appendChild(ta);
                ta.select(); document.execCommand('copy'); document.body.removeChild(ta);
                alert('Extraction JSON copied to clipboard.');
            }
        });

        document.getElementById('pxDownload').addEventListener('click', function () {
            if (!state.structure) return;
            var blob = new Blob([JSON.stringify(state.structure, null, 2)],
                                { type: 'application/json' });
            var url = URL.createObjectURL(blob);
            var a = document.createElement('a');
            a.href = url;
            a.download = 'structure-' + (state.form ? state.form.State : 'poa') +
                         '-' + (state.form ? state.form.Id : '') + '.json';
            document.body.appendChild(a); a.click(); document.body.removeChild(a);
            URL.revokeObjectURL(url);
        });
    }
    document.addEventListener('DOMContentLoaded', bindOnce);

    return { open: open, close: close };
}());
</script>

<!-- ═══════════════════════════════════════════════════════════════════════
     MAPPING SUMMARY MODAL (prototype screen 5)
     Launched by the grid's Map action. The grid is NOT extended for this —
     it stays a generic component; PoaMapping is a separate page module.
     ═══════════════════════════════════════════════════════════════════════ -->
<style>
    .pm-overlay {
        display: none;
        position: fixed; inset: 0; z-index: 4000;
        background: rgba(20, 24, 20, .55);
    }
    .pm-modal {
        position: absolute; top: 4%; left: 50%; transform: translateX(-50%);
        width: 1150px; max-width: 96vw; max-height: 92vh;
        background: #fff; border-radius: 10px;
        box-shadow: 0 18px 60px rgba(0,0,0,.35);
        display: flex; flex-direction: column;
        font-family: 'Segoe UI', Arial, sans-serif;
    }
    .pm-head {
        padding: 14px 20px; border-bottom: 1px solid #e2e6e2;
        display: flex; align-items: center; gap: 14px;
    }
    .pm-head h2 { margin: 0; font-size: 17px; color: #1a1e1a; }
    .pm-head .pm-sub { color: #7a837a; font-size: 12.5px; }
    .pm-close {
        margin-left: auto; border: none; background: none;
        font-size: 22px; color: #7a837a; cursor: pointer; line-height: 1;
    }
    .pm-close:hover { color: #1a1e1a; }
    .pm-chips { display: flex; gap: 10px; padding: 12px 20px 4px; }
    .pm-chip {
        flex: 1; border: 1px solid #e2e6e2; border-radius: 8px;
        padding: 8px 12px; text-align: center;
    }
    .pm-chip b { display: block; font-size: 20px; }
    .pm-chip span { font-size: 11.5px; color: #7a837a; }
    .pm-chip.total b { color: #1a1e1a; }
    .pm-chip.mapped  { background: #eef7ee; border-color: #bcd9bc; } .pm-chip.mapped b  { color: #2e7d2e; }
    .pm-chip.manual  { background: #fff8e1; border-color: #e4d091; } .pm-chip.manual b  { color: #9c7a00; }
    .pm-chip.ignored { background: #f4f5f6; }                        .pm-chip.ignored b { color: #7a837a; }
    .pm-chip.unassigned { background: #fdf0ef; border-color: #eac0bc; } .pm-chip.unassigned b { color: #c0392b; }
    .pm-body { padding: 10px 20px; overflow: auto; flex: 1; }
    .pm-table { width: 100%; border-collapse: collapse; font-size: 13px; }
    .pm-table th {
        text-align: left; padding: 8px 8px; background: #2e7d2e; color: #fff;
        font-size: 12px; position: sticky; top: 0;
    }
    .pm-table td { padding: 7px 8px; border-bottom: 1px solid #eef0ee; vertical-align: middle; }
    .pm-table tr:hover td { background: #f8faf8; }
    .pm-field-key { font-weight: 600; color: #1a1e1a; }
    .pm-field-label { color: #7a837a; font-size: 12px; }
    .pm-conf-low { color: #c0392b; font-weight: 600; }
    .pm-mode, .pm-target {
        padding: 5px 8px; border: 1px solid #cfd4cf; border-radius: 6px;
        font-size: 12.5px; background: #fff; max-width: 240px;
    }
    .pm-mode:focus, .pm-target:focus { outline: 2px solid #2e7d2e33; border-color: #2e7d2e; }
    .pm-target:disabled { background: #f4f5f6; color: #9aa09a; }
    .pm-status {
        display: inline-block; padding: 3px 10px; border-radius: 12px;
        font-size: 11.5px; font-weight: 600;
    }
    .pm-status.Mapped     { background: #eef7ee; color: #2e7d2e; }
    .pm-status.Manual     { background: #fff8e1; color: #9c7a00; }
    .pm-status.Ignored    { background: #f4f5f6; color: #7a837a; }
    .pm-status.Unassigned { background: #fdf0ef; color: #c0392b; }
    .pm-req { accent-color: #2e7d2e; }
    .pm-errors {
        display: none; margin: 8px 20px; padding: 10px 14px;
        background: #fdf0ef; border: 1px solid #eac0bc; border-radius: 8px;
        color: #c0392b; font-size: 12.5px; max-height: 120px; overflow: auto;
    }
    .pm-foot {
        padding: 12px 20px; border-top: 1px solid #e2e6e2;
        display: flex; gap: 10px; align-items: center;
    }
    .pm-btn {
        padding: 8px 18px; border-radius: 6px; font-size: 13px;
        cursor: pointer; border: 1px solid #cfd4cf; background: #fff; color: #1a1e1a;
    }
    .pm-btn:hover { background: #f4f5f6; }
    .pm-btn.primary { background: #2e7d2e; border-color: #2e7d2e; color: #fff; }
    .pm-btn.primary:hover { background: #256525; }
    .pm-btn:disabled { opacity: .55; cursor: not-allowed; }
    .pm-foot .pm-spacer { flex: 1; }
    .pm-loading { padding: 40px; text-align: center; color: #7a837a; }
</style>

<div class="pm-overlay" id="pmOverlay">
    <div class="pm-modal" role="dialog" aria-modal="true" aria-label="Mapping Summary">
        <div class="pm-head">
            <h2>Mapping Summary</h2>
            <span class="pm-sub" id="pmFormInfo"></span>
            <button type="button" class="pm-close" id="pmClose" title="Close">&times;</button>
        </div>
        <div class="pm-chips">
            <div class="pm-chip total"><b id="pmCntTotal">0</b><span>Total Fields</span></div>
            <div class="pm-chip mapped"><b id="pmCntMapped">0</b><span>Mapped</span></div>
            <div class="pm-chip manual"><b id="pmCntManual">0</b><span>Manual</span></div>
            <div class="pm-chip ignored"><b id="pmCntIgnored">0</b><span>Ignored</span></div>
            <div class="pm-chip unassigned"><b id="pmCntUnassigned">0</b><span>Unassigned</span></div>
        </div>
        <div class="pm-errors" id="pmErrors"></div>
        <div class="pm-body" id="pmBody">
            <div class="pm-loading">Loading mapping data…</div>
        </div>
        <div class="pm-foot">
            <button type="button" class="pm-btn" id="pmValidate">Validate</button>
            <span class="pm-spacer"></span>
            <button type="button" class="pm-btn" id="pmSaveDraft">Save Draft</button>
            <button type="button" class="pm-btn primary" id="pmPublish">Publish Mapping</button>
        </div>
    </div>
</div>

<script>
/* ═══════════════════════════════════════════════════════════════════════════
   PoaMapping — page module for the mapping process (POC of screens 4/5).
   Self-contained: own WebMethod caller, no AccordionGrid internals touched.
   Flow: open → GetMappingData → render rows (saved mapping OR suggestions)
   → live counters → Validate → Save Draft (Partial) / Publish (Mapped)
   → grid.updateRecord badge flip via the injected grid reference.
   ═══════════════════════════════════════════════════════════════════════ */
var PoaMapping = (function () {
    'use strict';

    var state = {
        agId: null,          // grid row id (for updateRecord)
        formId: null,
        grid: null,
        log: function () {},
        fields: [],          // template fields from the server
        rows: {}             // key -> { mode, target, required } (live)
    };

    function call(method, payload, ok) {
        // Shared page transport — identical to every working grid request.
        window.poaCallPageMethod(method, payload,
            function (inner) {
                if (inner && inner.Error) {
                    state.log('err', '[Mapping] ' + inner.Error);
                    alert(inner.Error);
                    return;
                }
                ok(inner);
            },
            function (err) {
                state.log('err', '[Mapping] ' + method + ' failed: ' + err);
                alert('Mapping call failed — see event log.');
            });
    }

    function esc(s) {
        var d = document.createElement('div');
        d.textContent = s == null ? '' : String(s);
        return d.innerHTML;
    }

    /* ── open ──────────────────────────────────────────────────────────── */
    function open(agId, record, grid, log) {
        state.agId = agId;
        state.formId = record.Id;
        state.grid = grid;
        state.log = log || function () {};
        state.rows = {};

        document.getElementById('pmFormInfo').textContent =
            record.Description + '  ·  ' + record.State +
            '  ·  current: ' + (record.MappingStatus || 'Not Mapped');
        document.getElementById('pmBody').innerHTML =
            '<div class="pm-loading">Loading mapping data…</div>';
        hideErrors();
        document.getElementById('pmOverlay').style.display = 'block';

        call('GetMappingData', { Id: record.Id }, function (data) {
            state.fields = data.Fields || [];
            render(data);
            state.log('info', '[Mapping] Loaded ' + state.fields.length +
                ' fields for id=' + record.Id +
                (data.Mapping ? ' (saved mapping applied)' : ' (suggestions applied)'));
        });
    }

    function close() {
        document.getElementById('pmOverlay').style.display = 'none';
    }

    /* ── render ────────────────────────────────────────────────────────── */
    function render(data) {
        var saved = {};
        if (data.Mapping) {
            data.Mapping.forEach(function (m) { saved[m.Key] = m; });
        }

        var opts = '<option value=""></option>';
        (data.DataSources || []).forEach(function (ds) {
            opts += '<option value="' + esc(ds) + '">' + esc(ds) + '</option>';
        });

        var html = '<table class="pm-table"><thead><tr>' +
            '<th style="width:200px;">Field</th>' +
            '<th style="width:90px;">Type</th>' +
            '<th style="width:44px;">Pg</th>' +
            '<th style="width:60px;">Conf</th>' +
            '<th style="width:120px;">Mode</th>' +
            '<th>Mapped To (C3 data source)</th>' +
            '<th style="width:56px;">Req</th>' +
            '<th style="width:100px;">Status</th>' +
            '</tr></thead><tbody>';

        state.fields.forEach(function (f) {
            // Saved mapping wins; else server suggestions (auto-map by type)
            var init = saved[f.Key] ||
                { Mode: f.SuggestedMode || '', Target: f.SuggestedTarget || '', Required: f.Required };
            state.rows[f.Key] = {
                mode: init.Mode || '',
                target: init.Target || '',
                required: !!init.Required
            };

            var confCls = f.Confidence < 0.6 ? ' class="pm-conf-low"' : '';
            html += '<tr data-key="' + esc(f.Key) + '">' +
                '<td><div class="pm-field-key">' + esc(f.Key) + '</div>' +
                    '<div class="pm-field-label">' + esc(f.Label) + '</div></td>' +
                '<td>' + esc(f.Type) + '</td>' +
                '<td>' + f.Page + '</td>' +
                '<td' + confCls + '>' + (f.Confidence * 100).toFixed(0) + '%</td>' +
                '<td><select class="pm-mode">' +
                    '<option value=""></option>' +
                    '<option value="Mapped">Mapped</option>' +
                    '<option value="Manual">Manual</option>' +
                    '<option value="Ignored">Ignored</option>' +
                '</select></td>' +
                '<td><select class="pm-target">' + opts + '</select></td>' +
                '<td style="text-align:center;"><input type="checkbox" class="pm-req"></td>' +
                '<td><span class="pm-status"></span></td>' +
                '</tr>';
        });

        html += '</tbody></table>';
        document.getElementById('pmBody').innerHTML = html;

        // Init controls from state + bind
        state.fields.forEach(function (f) {
            var tr = rowEl(f.Key);
            var row = state.rows[f.Key];
            tr.querySelector('.pm-mode').value = row.mode;
            tr.querySelector('.pm-target').value = row.target;
            tr.querySelector('.pm-req').checked = row.required;

            tr.querySelector('.pm-mode').addEventListener('change', function () {
                row.mode = this.value;
                if (row.mode !== 'Mapped') row.target = '';
                syncRow(f.Key);
                recount();
            });
            tr.querySelector('.pm-target').addEventListener('change', function () {
                row.target = this.value;
                syncRow(f.Key);
            });
            tr.querySelector('.pm-req').addEventListener('change', function () {
                row.required = this.checked;
            });
            syncRow(f.Key);
        });
        recount();
    }

    function rowEl(key) {
        return document.querySelector('#pmBody tr[data-key="' + key + '"]');
    }

    function syncRow(key) {
        var tr = rowEl(key);
        var row = state.rows[key];
        var target = tr.querySelector('.pm-target');
        target.disabled = row.mode !== 'Mapped';
        if (row.mode !== 'Mapped') target.value = '';
        else target.value = row.target;

        var st = row.mode === '' ? 'Unassigned' : row.mode;
        var chip = tr.querySelector('.pm-status');
        chip.textContent = st;
        chip.className = 'pm-status ' + st;
    }

    function recount() {
        var c = { Mapped: 0, Manual: 0, Ignored: 0, Unassigned: 0 };
        Object.keys(state.rows).forEach(function (k) {
            var m = state.rows[k].mode;
            if (m === '') c.Unassigned++; else c[m]++;
        });
        document.getElementById('pmCntTotal').textContent = state.fields.length;
        document.getElementById('pmCntMapped').textContent = c.Mapped;
        document.getElementById('pmCntManual').textContent = c.Manual;
        document.getElementById('pmCntIgnored').textContent = c.Ignored;
        document.getElementById('pmCntUnassigned').textContent = c.Unassigned;
    }

    /* ── validate / save / publish ─────────────────────────────────────── */
    function collect() {
        return {
            FormId: state.formId,
            Fields: state.fields.map(function (f) {
                var r = state.rows[f.Key];
                return { Key: f.Key, Mode: r.mode, Target: r.target, Required: r.required };
            })
        };
    }

    function clientValidate() {
        var errs = [];
        state.fields.forEach(function (f) {
            var r = state.rows[f.Key];
            if (r.mode === '') errs.push(f.Key + ': unassigned.');
            else if (r.mode === 'Mapped' && !r.target) errs.push(f.Key + ': Mapped but no data source.');
        });
        return errs;
    }

    function showErrors(errs) {
        var box = document.getElementById('pmErrors');
        box.innerHTML = errs.map(function (e) { return '• ' + esc(e); }).join('<br>');
        box.style.display = 'block';
    }
    function hideErrors() {
        document.getElementById('pmErrors').style.display = 'none';
    }

    function applyStatus(status) {
        state.grid.updateRecord(state.agId, { MappingStatus: status });
        state.log('ok', '[Mapping] id=' + state.formId + ' → MappingStatus="' + status + '"');
    }

    function bindOnce() {
        document.getElementById('pmClose').addEventListener('click', close);
        document.getElementById('pmOverlay').addEventListener('click', function (e) {
            if (e.target === this) close();
        });

        document.getElementById('pmValidate').addEventListener('click', function () {
            var errs = clientValidate();
            if (errs.length) showErrors(errs);
            else { hideErrors(); alert('Mapping is valid — ready to publish.'); }
        });

        document.getElementById('pmSaveDraft').addEventListener('click', function () {
            call('SaveMappingDraft', { mapping: collect() }, function (resp) {
                applyStatus(resp.Status);
                hideErrors();
                alert('Draft saved — status: ' + resp.Status);
            });
        });

        document.getElementById('pmPublish').addEventListener('click', function () {
            var errs = clientValidate();
            if (errs.length) { showErrors(errs); return; }
            call('PublishMapping', { mapping: collect() }, function (resp) {
                if (resp.Errors && resp.Errors.length) {
                    showErrors(resp.Errors);   // server is the authority
                    applyStatus(resp.Status);
                    return;
                }
                applyStatus(resp.Status);      // "Mapped" → Generate now visible
                close();
                alert('Mapping published — Generate is now available for this template.');
            });
        });
    }
    document.addEventListener('DOMContentLoaded', bindOnce);

    return { open: open, close: close };
}());
</script>

</body>
</html>
