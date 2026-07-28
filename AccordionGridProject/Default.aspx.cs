using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Services;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace AccordionGridProject
{
    public partial class Default : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
                LoadFirstPage();
        }

        // ─────────────────────────────────────────────────────────────────────
        // PAGE LOAD — push first page + totalCount to the browser.
        // Every subsequent page/search/sort/filter goes through GetPage().
        // ─────────────────────────────────────────────────────────────────────
        private void LoadFirstPage()
        {
            const int firstPageSize = 10;
            int totalCount;
            var data = FakePoaFormsService.GetAllForms(
                itemsPerPage: firstPageSize,
                pageNumber: 1,
                totalCount: out totalCount);

            var payload = new
            {
                items = FlattenRecords(data),
                totalCount = totalCount,
                pageSize = firstPageSize,
                page = 1
            };

            var json = JsonConvert.SerializeObject(payload, new JsonSerializerSettings
            {
                StringEscapeHandling = StringEscapeHandling.EscapeHtml,
                NullValueHandling = NullValueHandling.Include
            });

            HiddenGridData.Value = json;
            ClientScript.RegisterStartupScript(
                GetType(), "poaInitialData",
                "window.poaInitialData = " + json + ";",
                addScriptTags: true);

            // Load combo box lookups separately so the pipeline is
            // easy to verify and easy to swap to the real service.
            LoadLookups();
        }

        // ─────────────────────────────────────────────────────────────────────
        // LOAD LOOKUPS
        //
        // Builds a plain C# anonymous object with one collection per combo box.
        // Each collection is a list of { value, label } objects — the same shape
        // the AccordionGrid combo boxes consume.
        //
        // THIS METHOD IS THE DIAGNOSTIC BASELINE.
        // The object below is hardcoded so you can verify the full pipeline
        // (C# → JsonConvert → RegisterStartupScript → window.poaLookups → JS)
        // works before connecting to the real service.
        //
        // TO SWITCH TO THE REAL SERVICE:
        // Replace each hardcoded list below with:
        //   PoaFormsService.GetServiceTypes()
        //       .Select(x => new { value = x.Id, label = x.Name }).ToList()
        // (repeat for each lookup)
        // ─────────────────────────────────────────────────────────────────────
        private void LoadLookups()
        {
            // ── Each list mirrors what your real lookup table returns ──────────
            // value = FK id (int)  |  label = display text (string)
            // These must match the real service output exactly.

            var serviceTypes = new[]
            {
                new { value = 1, label = "Full"    },
                new { value = 2, label = "Partial" },
                new { value = 3, label = "Limited" }
            };

            var poaFormTypes = new[]
            {
                new { value = 1, label = "POA"  },
                new { value = 2, label = "2848" },
                new { value = 3, label = "8821" }
            };

            var formUses = new[]
            {
                new { value = 1, label = "Filing"          },
                new { value = 2, label = "Representation"  },
                new { value = 3, label = "Both"            }
            };

            var poaTypes = new[]
            {
                new { value = 1, label = "Tax"       },
                new { value = 2, label = "Financial" },
                new { value = 3, label = "Medical"   }
            };

            var signatureTypes = new[]
            {
                new { value = 1, label = "Digital"    },
                new { value = 2, label = "Electronic" },
                new { value = 3, label = "Wet"        }
            };

            var onlineRequirements = new[]
            {
                new { value = 1, label = "None"     },
                new { value = 2, label = "Required" },
                new { value = 3, label = "Optional" }
            };

            var returnTypes = new[]
            {
                new { value = 1, label = "Mail"   },
                new { value = 2, label = "Fax"    },
                new { value = 3, label = "E-File" },
                new { value = 4, label = "Portal" }
            };

            var mailCenters = new[]
            {
                new { value = 3,  label = "Mail Center 3"  },
                new { value = 5,  label = "Mail Center 5"  },
                new { value = 6,  label = "Mail Center 6"  },
                new { value = 7,  label = "Mail Center 7"  },
                new { value = 8,  label = "Mail Center 8"  },
                new { value = 9,  label = "Mail Center 9"  },
                new { value = 10, label = "Mail Center 10" },
                new { value = 11, label = "Mail Center 11" },
                new { value = 12, label = "Mail Center 12" }
            };

            // States: value = state code (string), label = state code
            // Matches GetStates() which returns code as Id.
            var stateCodes = "AL,AK,AZ,AR,CA,CO,CT,DE,FL,GA,HI,ID,IL,IN,IA,KS,KY,LA,ME,MD," +
                             "MA,MI,MN,MS,MO,MT,NE,NV,NH,NJ,NM,NY,NC,ND,OH,OK,OR,PA,RI,SC," +
                             "SD,TN,TX,UT,VT,VA,WA,WV,WI,WY";

            var states = stateCodes.Split(',')
                .Select(s => new { value = s, label = s })
                .ToList();

            // ── Build the single lookups object ───────────────────────────────
            var lookups = new
            {
                serviceTypes = serviceTypes,
                poaFormTypes = poaFormTypes,
                formUses = formUses,
                poaTypes = poaTypes,
                signatureTypes = signatureTypes,
                onlineRequirements = onlineRequirements,
                returnTypes = returnTypes,
                mailCenters = mailCenters,
                states = states
            };

            // ── Serialize ─────────────────────────────────────────────────────
            var lookupsJson = JsonConvert.SerializeObject(
                lookups,
                new JsonSerializerSettings
                {
                    StringEscapeHandling = StringEscapeHandling.EscapeHtml
                });

            // ── Inject into the page ──────────────────────────────────────────
            // PRIMARY: HiddenLookups hidden field — always in the rendered HTML,
            // no timing dependency on RegisterStartupScript injection order.
            // Same pattern as HiddenGridData for the grid data.
            HiddenLookups.Value = lookupsJson;

            // SECONDARY: RegisterStartupScript — sets window.poaLookups as
            // a fallback in case the hidden field read fails.
            ClientScript.RegisterStartupScript(
                type: GetType(),
                key: "poaLookups",
                script: "window.poaLookups = " + lookupsJson + ";",
                addScriptTags: true);
        }

        // Maps service LookupItem { Id, Name } → grid option { value, label }
        private static List<object> ToOptions(IEnumerable<LookupItem> items)
        {
            return items.Select(i => (object)new { value = i.Id, label = i.Name }).ToList();
        }

        // ─────────────────────────────────────────────────────────────────────
        // GET PAGE — dataLoader calls this on every page/search/sort/filter.
        // Replace FakePoaFormsService with IPoaFormsService in real code.
        // ─────────────────────────────────────────────────────────────────────
        [WebMethod]
        public static string GetPage(int page, int pageSize,
                                     string search, string filter,
                                     string sortKey, string sortDir)
        {
            if (page <= 0) page = 1;
            if (pageSize <= 0) pageSize = 10;
            if (pageSize > 100) pageSize = 100;

            int totalCount;
            var data = FakePoaFormsService.GetAllForms(
                itemsPerPage: pageSize,
                pageNumber: page,
                totalCount: out totalCount,
                search: search,
                filterState: filter,
                sortKey: sortKey,
                sortDir: sortDir);

            return JsonConvert.SerializeObject(new
            {
                items = FlattenRecords(data),
                totalCount = totalCount
            });
        }

        // ─────────────────────────────────────────────────────────────────────
        // INSERT FORM
        // Called by onSave when e.isNew === true.
        // Returns the new Id and a server-stamped LastUpdated so the grid
        // can update the in-memory record without a full reload.
        //
        // REAL IMPLEMENTATION:
        //   var model = MapDtoToModel(form);
        //   model.LastUpdated = DateTime.UtcNow;
        //   int newId = PoaFormsService.InsertForm(model);
        //   return new { Id = newId,
        //                LastUpdated = model.LastUpdated.Value.ToString("MM/dd/yyyy hh:mm tt") };
        // ─────────────────────────────────────────────────────────────────────
        // INSERT FORM
        // The DTO now carries foreign-key IDs directly from the combo boxes
        // (ServiceTypeId, FormTypeId, …) so no string→id lookup is needed.
        // State arrives as the abbreviation and is resolved to StateId here.
        //
        // REAL IMPLEMENTATION:
        //   var entity = new poa_forms
        //   {
        //       description       = form.Description,
        //       active            = form.Active,
        //       mail_center_id    = form.MailCenterId,
        //       service_type_id   = form.ServiceTypeId,        // ← direct FK
        //       form_type_id      = form.FormTypeId,
        //       form_use_id       = form.FormUseId,
        //       poa_type_id       = form.PoaTypeId,
        //       signature_type_id = form.SignatureTypeId,
        //       return_type_id    = form.ReturnTypeId,
        //       online_requirement_id = form.OnlineRequirementId,
        //       state_id          = _context.state_codes
        //                              .Where(s => s.abbreviation == form.State)
        //                              .Select(s => (int?)s.id).FirstOrDefault(),
        //       document_reference = form.DocumentReference,
        //       file_name          = form.FileName,
        //       file_extension     = form.FileExtension,
        //       last_updated       = DateTime.UtcNow
        //   };
        //   _context.poa_forms.Add(entity);
        //   _context.SaveChanges();
        //   return new { Id = entity.id,
        //                LastUpdated = entity.last_updated.Value.ToString("MM/dd/yyyy hh:mm tt") };
        // ─────────────────────────────────────────────────────────────────────
        [WebMethod]
        public static string InsertForm(PoaFormDto form)
        {
            // ── POC stub ────────────────────────────────────────────────────
            var newId = new Random().Next(100, 9999);
            var lastUpdated = DateTime.Now.ToString("MM/dd/yyyy hh:mm tt");

            // UpdatedBy is stamped SERVER-SIDE from the session user — it is
            // never sent by the client and is NOT a PoaFormDto property.
            // REAL IMPLEMENTATION (C3):
            //   var currentUser = HttpContext.Current?.Session?["c3User"] as classC3User;
            //   entity.updated_by = currentUser != null ? currentUser.DisplayName : "system";
            var updatedBy = GetCurrentUserName();

            System.Diagnostics.Trace.TraceInformation(
                "[InsertForm] Simulated insert — description={0}, serviceTypeId={1}, " +
                "poaFormTypeId={2}, state={3}, newId={4}, updatedBy={5}",
                form.Description, form.ServiceTypeId, form.PoaFormTypeId, form.State,
                newId, updatedBy);

            return JsonConvert.SerializeObject(new
            {
                Id = newId,
                LastUpdated = lastUpdated,
                UpdatedBy = updatedBy
            });
        }

        // ─────────────────────────────────────────────────────────────────────
        // UPDATE FORM
        // Called by onSave when e.isNew === false.
        // Returns the server-stamped LastUpdated.
        //
        // REAL IMPLEMENTATION:
        //   var model = MapDtoToModel(form);
        //   model.LastUpdated = DateTime.UtcNow;
        //   PoaFormsService.UpdateForm(model);
        //   return new { LastUpdated = model.LastUpdated.Value.ToString("MM/dd/yyyy hh:mm tt") };
        // ─────────────────────────────────────────────────────────────────────
        [WebMethod]
        public static string UpdateForm(PoaFormDto form)
        {
            // ── POC stub ────────────────────────────────────────────────────
            var lastUpdated = DateTime.Now.ToString("MM/dd/yyyy hh:mm tt");

            // Stamp the editor server-side (same pattern as InsertForm).
            var updatedBy = GetCurrentUserName();

            System.Diagnostics.Trace.TraceInformation(
                "[UpdateForm] Simulated update — id={0}, description={1}, updatedBy={2}",
                form.Id, form.Description, updatedBy);

            return JsonConvert.SerializeObject(new
            {
                LastUpdated = lastUpdated,
                UpdatedBy = updatedBy
            });
        }

        // ─────────────────────────────────────────────────────────────────────
        // CURRENT USER — POC stub returns a fixed name.
        //
        // REAL IMPLEMENTATION (C3WebFramework):
        //   var currentUser = HttpContext.Current?.Session?["c3User"] as classC3User;
        //   return currentUser != null ? currentUser.DisplayName : "system";
        // (Adjust the session key / property to your classC3User definition —
        //  the same one InsertForm already reads for ProviderUserKey.)
        // ─────────────────────────────────────────────────────────────────────
        private static string GetCurrentUserName()
        {
            return "developer";   // POC: fixed name so the column is visibly stamped
        }

        // ─────────────────────────────────────────────────────────────────────
        // DELETE FORM
        // Called by the Delete action button after user confirms.
        // Returns success:true so the JS can call grid.removeRecord() only
        // after the server confirms deletion.
        //
        // REAL IMPLEMENTATION:
        //   PoaFormsService.DeleteForm(id);
        //   return new { Success = true };
        // ─────────────────────────────────────────────────────────────────────
        [WebMethod]
        public static string DeleteForm(int Id)
        {
            // ── POC stub ────────────────────────────────────────────────────
            System.Diagnostics.Trace.TraceInformation(
                "[DeleteForm] Simulated delete — id={0}", Id);

            return JsonConvert.SerializeObject(new { Success = true });
        }

        [WebMethod]
        public static string TriggerExtraction(int Id, bool force = false)
        {
            /* ── SERVER-SIDE GATE (the authority) ────────────────────────────
               The UI hides/disables buttons, but a stale page, a double
               submit, or a crafted request can still arrive — so every rule
               is enforced here as well.
                 no record           → error
                 no document         → error (nothing to extract)
                 In Progress         → error (already running; blocks the
                                       double-click race)
                 Completed + !force  → error (must use Re-extract explicitly)
                 Completed + force   → allowed (re-extraction)
            ─────────────────────────────────────────────────────────────── */
            var form = FakePoaFormsService.GetById(Id);
            if (form == null)
                return JsonConvert.SerializeObject(new { Error = "Template not found: " + Id });

            if (string.IsNullOrWhiteSpace(form.DocumentReference))
                return JsonConvert.SerializeObject(new
                {
                    Error = "No document uploaded for this template — nothing to extract."
                });

            if (form.ExtractionStatus == "In Progress")
                return JsonConvert.SerializeObject(new
                {
                    Error = "Extraction is already running for this template.",
                    Status = "In Progress"
                });

            if (form.ExtractionStatus == "Completed" && !force)
                return JsonConvert.SerializeObject(new
                {
                    Error = "This template is already extracted. Use Re-extract to run it again.",
                    Status = "Completed",
                    AlreadyExtracted = true
                });

            bool isReextraction = form.ExtractionStatus == "Completed";
            var jobId = "JOB-" + Id + "-" + Guid.NewGuid().ToString("N").Substring(0, 8).ToUpper();

            // Status is persisted BEFORE the job is queued: the client's
            // optimistic badge must be backed by real state or it reverts on
            // the next page load.
            FakePoaFormsService.UpdateExtractionStatus(Id, "In Progress");
            FakeExtractionService.StartRun(Id, jobId, isReextraction);

            // A new run replaces the stored artifact — clear the old structure
            // blob so the next viewer open reads the fresh output.
            if (isReextraction)
                FakeBlobStorageService.Delete(FakeBlobStorageService.StructurePath(Id));

            System.Diagnostics.Trace.TraceInformation(
                "[TriggerExtraction] id={0} jobId={1} reextraction={2}", Id, jobId, isReextraction);

            return JsonConvert.SerializeObject(new
            {
                JobId = jobId,
                Status = "In Progress",
                IsReextraction = isReextraction
            });
        }

        [WebMethod]
        public static string GetExtractionStatus(int Id)
        {
            // POC: the run completes a few seconds after it starts so the
            // polling loop and the In Progress badge are actually observable.
            // Production: a single-column read of extraction_status.
            var status = FakeExtractionService.EvaluateStatus(Id);
            return JsonConvert.SerializeObject(new { Status = status });
        }

        /// <summary>Returns the normalized TemplateStructure produced by the
        /// extraction, for the "View JSON" viewer. Production: read the
        /// structure blob referenced by the extraction row.</summary>
        [WebMethod]
        public static string GetExtractionStructure(int Id)
        {
            var form = FakePoaFormsService.GetById(Id);
            if (form == null)
                return JsonConvert.SerializeObject(new { Error = "Template not found: " + Id });

            if (form.ExtractionStatus != "Completed")
                return JsonConvert.SerializeObject(new
                {
                    Error = "No extraction output yet (status: " + form.ExtractionStatus + ")."
                });

            var structure = GetOrCreateStructure(form);

            return JsonConvert.SerializeObject(new
            {
                Form = new { form.Id, form.Description, form.State },
                Run = FakeExtractionService.GetRunInfo(Id, form),
                Source = new
                {
                    FileName = string.IsNullOrEmpty(form.FileName)
                        ? (form.Description + ".pdf") : form.FileName,
                    Reference = form.DocumentReference,
                    Size = "1.24 MB"   // POC: production reads the blob's length
                },
                Structure = structure
            });
        }

        /* ── SINGLE SOURCE OF TRUTH for the extracted structure ─────────────
           Blob-first read; on miss the engine output is generated, SAVED to
           the blob, then served — write-once/read-many like production.
           BOTH the JSON viewer (GetExtractionStructure) and the mapping
           modal (GetMappingData) go through here, so what the user maps is
           EXACTLY what the viewer displays — one artifact, two windows.
        ─────────────────────────────────────────────────────────────────── */
        private static Newtonsoft.Json.Linq.JToken GetOrCreateStructure(PoaFormModel form)
        {
            string blobPath = FakeBlobStorageService.StructurePath(form.Id);
            string blobJson = FakeBlobStorageService.GetJson(blobPath);

            if (blobJson == null)
            {
                var generated = FakeExtractionService.GetStructure(
                    form.Id, form.State, form.Description);
                blobJson = JsonConvert.SerializeObject(generated, Formatting.Indented);
                FakeBlobStorageService.SaveJson(blobPath, blobJson);
            }

            return Newtonsoft.Json.Linq.JToken.Parse(blobJson);
        }

        /* ═══════════════════════════════════════════════════════════════════
           FAKE BLOB STORAGE — mimics the Azure Blob container that holds the
           extraction artifacts. Production swap:
             GetJson  → BlobDocumentService.GetDocumentAsync(path, container)
             SaveJson → BlobDocumentService.UploadAsync(path, container, json)
           Path convention (matches the architecture doc):
             poa-extraction/{formId}/structure-v{schemaVersion}-{timestamp}.json
           Pre-seeded with a realistic normalized TemplateStructure for the
           already-Completed seed rows so the viewer always has content.
           ═══════════════════════════════════════════════════════════════════ */
        private static class FakeBlobStorageService
        {
            private static readonly Dictionary<string, string> _blobs =
                new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            private static readonly object _lock = new object();


            public static string StructurePath(int formId)
            {
                return "poa-extraction/" + formId + "/structure-v1.json";
            }

            public static string GetJson(string path)
            {
                lock (_lock)
                {
                    string json;
                    if (_blobs.TryGetValue(path, out json))
                    {
                        System.Diagnostics.Trace.TraceInformation(
                            "[FakeBlob] GET {0} ({1} bytes)", path, json.Length);
                        return json;
                    }
                    System.Diagnostics.Trace.TraceInformation("[FakeBlob] MISS {0}", path);
                    return null;
                }
            }

            public static void Delete(string path)
            {
                lock (_lock)
                {
                    if (_blobs.Remove(path))
                        System.Diagnostics.Trace.TraceInformation("[FakeBlob] DELETE {0}", path);
                }
            }

            public static void SaveJson(string path, string json)
            {
                lock (_lock)
                {
                    _blobs[path] = json;
                    System.Diagnostics.Trace.TraceInformation(
                        "[FakeBlob] PUT {0} ({1} bytes)", path, json.Length);
                }
            }
        }

        /// <summary>POC stand-in for the extraction pipeline + artifact store.
        /// Production: Hangfire job writes status/blob refs; this reads them.</summary>
        private static class FakeExtractionService
        {
            private const int SimulatedRunSeconds = 8;   // long enough to see "In Progress"

            private class Run
            {
                public string JobId;
                public DateTime StartedUtc;
                public DateTime? CompletedUtc;
                public bool IsReextraction;
                public int Version;
            }

            private static readonly Dictionary<int, Run> _runs = new Dictionary<int, Run>();
            private static readonly object _lock = new object();

            public static void StartRun(int formId, string jobId, bool isReextraction)
            {
                lock (_lock)
                {
                    int version = 1;
                    Run existing;
                    if (_runs.TryGetValue(formId, out existing)) version = existing.Version + 1;

                    _runs[formId] = new Run
                    {
                        JobId = jobId,
                        StartedUtc = DateTime.UtcNow,
                        IsReextraction = isReextraction,
                        Version = version
                    };
                }
            }

            /// <summary>Simulates job progress and stamps the terminal status
            /// onto the record, exactly as the real job would.</summary>
            public static string EvaluateStatus(int formId)
            {
                Run run;
                lock (_lock)
                {
                    if (!_runs.TryGetValue(formId, out run))
                    {
                        var f = FakePoaFormsService.GetById(formId);
                        return f != null ? f.ExtractionStatus : "Not Started";
                    }
                }

                if ((DateTime.UtcNow - run.StartedUtc).TotalSeconds < SimulatedRunSeconds)
                    return "In Progress";

                lock (_lock)
                {
                    if (run.CompletedUtc == null)
                        run.CompletedUtc = run.StartedUtc.AddSeconds(SimulatedRunSeconds);
                }
                FakePoaFormsService.UpdateExtractionStatus(formId, "Completed");
                return "Completed";
            }

            /// <summary>Run metadata for the viewer's status bar. Seed rows
            /// that were "Completed" before any run get fabricated times off
            /// the record's LastUpdated so the bar is never empty.</summary>
            public static object GetRunInfo(int formId, PoaFormModel form)
            {
                Run run;
                lock (_lock) { _runs.TryGetValue(formId, out run); }

                DateTime started, completed;
                if (run != null)
                {
                    started = run.StartedUtc;
                    completed = run.CompletedUtc ?? run.StartedUtc.AddSeconds(SimulatedRunSeconds);
                }
                else
                {
                    completed = form.LastUpdated ?? DateTime.UtcNow;
                    started = completed.AddMinutes(-4).AddSeconds(-12);
                }

                var duration = completed - started;
                string durationText = duration.TotalMinutes >= 1
                    ? string.Format("{0}m {1}s", (int)duration.TotalMinutes, duration.Seconds)
                    : string.Format("{0}s", (int)duration.TotalSeconds);

                return new
                {
                    Status = "Completed",
                    Started = started.ToLocalTime().ToString("MM/dd/yyyy hh:mm tt"),
                    Completed = completed.ToLocalTime().ToString("MM/dd/yyyy hh:mm tt"),
                    Duration = durationText
                };
            }

            public static int GetVersion(int formId)
            {
                lock (_lock)
                {
                    Run run;
                    return _runs.TryGetValue(formId, out run) ? run.Version : 1;
                }
            }

            /// <summary>The normalized TemplateStructure the engine emits.
            /// Fields mirror the validated CA DE-48 run.</summary>
            public static object GetStructure(int formId, string state, string description)
            {
                return new
                {
                    SchemaVersion = 1,
                    EngineVersion = "1.2.0",
                    ProfileName = string.IsNullOrEmpty(state) ? "default" : state,
                    SourceModel = "prebuilt-layout",
                    ExtractionVersion = GetVersion(formId),
                    ExtractedUtc = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"),
                    Pages = new[] { new { Number = 1, Width = 8.5f, Height = 11f, Unit = "inch" } },
                    Fields = FakeMappingService.GetTemplateFields(state),
                    SignatureAreas = new[]
                    {
                        new { Label = "Signature", Page = 1,
                              Rect = new { X = 0.075f, Y = 0.836f, W = 0.34f, H = 0.02f },
                              Confidence = 0.50f }
                    },
                    Warnings = new[]
                    {
                        "page 1: 4 zone(s) below confidence 0.60",
                        "page 1: 6 checkbox zone(s) detected by lexicon fallback — verify positions"
                    }
                };
            }
        }

        /* ═══════════════════════════════════════════════════════════════════
           MAPPING PROCESS (POC — mirrors prototype screens 4/5)
           Flow: Extract Completed → Map opens the Mapping Summary modal →
           per-field assignment (Mapped-to-C3-path | Manual | Ignored) →
           Validate → Save Draft (Partial) / Publish (Mapped) → grid badge.
           Production: mapping JSON persists next to the TemplateStructure
           (poa_form_mapping row + blob), consumed by the Generate pipeline.
           ═══════════════════════════════════════════════════════════════════ */

        public class MappingFieldDto
        {
            public string Key { get; set; }
            public string Mode { get; set; }      // Mapped | Manual | Ignored | "" (unassigned)
            public string Target { get; set; }    // C3 path when Mode == Mapped
            public bool Required { get; set; }
        }

        public class MappingDto
        {
            public int FormId { get; set; }
            public List<MappingFieldDto> Fields { get; set; }
        }

        /// <summary>Returns everything the mapping modal needs in ONE call:
        /// form header, the extracted TemplateStructure fields, the C3 data
        /// source catalog, and any previously saved mapping.</summary>
        [WebMethod]
        public static string GetMappingData(int Id)
        {
            var form = FakePoaFormsService.GetById(Id);
            if (form == null)
                return JsonConvert.SerializeObject(new { Error = "Form not found: " + Id });
            if (form.ExtractionStatus != "Completed")
                return JsonConvert.SerializeObject(new
                {
                    Error = "Extraction must be Completed before mapping (current: "
                            + form.ExtractionStatus + ")."
                });

            // SAME artifact the JSON viewer shows — fields come from the
            // stored structure blob, not a separate list. One extraction,
            // one truth: what you view is what you map.
            var structureForMapping = GetOrCreateStructure(form);
            var fields = structureForMapping["Fields"];
            var saved = FakeMappingService.GetSavedMapping(Id);

            return JsonConvert.SerializeObject(new
            {
                Form = new { form.Id, form.Description, form.State, form.MappingStatus },
                Fields = fields,
                DataSources = FakeMappingService.DataSourceCatalog(),
                Mapping = saved   // null when never saved — modal applies suggestions
            });
        }

        /// <summary>Draft save — no validation gate. Status: Partial when at
        /// least one field is assigned, else Not Mapped.</summary>
        [WebMethod]
        public static string SaveMappingDraft(MappingDto mapping)
        {
            if (mapping == null || mapping.FormId <= 0)
                return JsonConvert.SerializeObject(new { Error = "Invalid mapping payload." });

            FakeMappingService.SaveMapping(mapping.FormId, mapping.Fields);

            bool any = mapping.Fields != null &&
                       mapping.Fields.Any(f => !string.IsNullOrEmpty(f.Mode));
            string status = any ? "Partial" : "Not Mapped";
            FakePoaFormsService.UpdateMappingStatus(mapping.FormId, status);

            return JsonConvert.SerializeObject(new { Status = status });
        }

        /// <summary>Publish — server-side validation is the authority (the
        /// client Validate button is convenience only): every field needs a
        /// Mode; Mapped needs a Target. Valid → Mapped, else errors.</summary>
        [WebMethod]
        public static string PublishMapping(MappingDto mapping)
        {
            if (mapping == null || mapping.FormId <= 0)
                return JsonConvert.SerializeObject(new { Error = "Invalid mapping payload." });

            var errors = new List<string>();
            if (mapping.Fields == null || mapping.Fields.Count == 0)
            {
                errors.Add("No fields in mapping.");
            }
            else
            {
                foreach (var f in mapping.Fields)
                {
                    if (string.IsNullOrEmpty(f.Mode))
                        errors.Add(f.Key + ": unassigned — choose Mapped, Manual, or Ignored.");
                    else if (f.Mode == "Mapped" && string.IsNullOrEmpty(f.Target))
                        errors.Add(f.Key + ": Mapped but no data source selected.");
                }
            }

            if (errors.Count > 0)
                return JsonConvert.SerializeObject(new { Status = "Partial", Errors = errors });

            FakeMappingService.SaveMapping(mapping.FormId, mapping.Fields);
            FakePoaFormsService.UpdateMappingStatus(mapping.FormId, "Mapped");

            return JsonConvert.SerializeObject(new { Status = "Mapped", Errors = new List<string>() });
        }

        /// <summary>Legacy stub kept for compatibility — the map action now
        /// opens the Mapping Summary modal instead of calling this.</summary>
        [WebMethod]
        public static string TriggerMapping(int Id)
        {
            System.Diagnostics.Trace.TraceInformation(
                "[TriggerMapping] Legacy stub — id={0}", Id);
            return JsonConvert.SerializeObject(new { Status = "Partial", RedirectUrl = (string)null });
        }

        /// <summary>POC stand-ins for ITemplateStructureService (extracted
        /// fields) + IPoaMappingService (saved mappings) + the C3 catalog.
        /// Production: fields come from the stored TemplateStructure JSON;
        /// mappings persist to poa_form_mapping (+ blob); catalog comes from
        /// the C3 metadata service.</summary>
        private static class FakeMappingService
        {
            // FormId -> saved mapping (survives postbacks like the forms list)
            private static readonly Dictionary<int, List<MappingFieldDto>> _store =
                new Dictionary<int, List<MappingFieldDto>>();
            private static readonly object _lock = new object();

            public static void SaveMapping(int formId, List<MappingFieldDto> fields)
            {
                lock (_lock)
                {
                    _store[formId] = fields ?? new List<MappingFieldDto>();
                }
            }

            public static List<MappingFieldDto> GetSavedMapping(int formId)
            {
                lock (_lock)
                {
                    List<MappingFieldDto> saved;
                    return _store.TryGetValue(formId, out saved) ? saved : null;
                }
            }

            /// <summary>Extracted fields as the NormalizerService would emit
            /// (subset of the validated CA DE-48 run). SuggestedTarget /
            /// SuggestedMode = auto-suggestions by canonical type, applied by
            /// the modal only when no saved mapping exists.</summary>
            public static object[] GetTemplateFields(string state)
            {
                _rowY = 0.10f;   // deterministic rects on every call
                return new object[]
                {
                    F("AccountNumber",  "CA Employer Payroll Tax Account Number", "AccountNumber", 1, 0.97f, "inline-label",   "C3.Company.PayrollAccountNumber", "Mapped", true),
                    F("TaxId",          "Federal Employer Identification Number", "TaxId",         1, 0.96f, "inline-label",   "C3.Company.EIN",                  "Mapped", true),
                    F("BusinessName",   "Business Name (Or Doing Business As)",   "Text",          1, 0.95f, "inline-label",   "C3.Company.Name",                 "Mapped", true),
                    F("Address",        "Business Mailing Address",               "Address",       1, 0.95f, "inline-label",   "C3.Company.Address",              "Mapped", true),
                    F("City",           "City",                                   "City",          1, 0.96f, "inline-label",   "C3.Company.City",                 "Mapped", false),
                    F("State",          "State",                                  "State",         1, 0.95f, "inline-label",   "C3.Company.State",                "Mapped", false),
                    F("Zip",            "ZIP Code",                               "Zip",           1, 0.96f, "inline-label",   "C3.Company.Zip",                  "Mapped", false),
                    F("Phone",          "Business Phone Number",                  "Phone",         1, 0.94f, "inline-label",   "C3.Company.Phone",                "Mapped", false),
                    F("RepresentativeName", "Representative Name",                "Text",          1, 0.95f, "inline-label",   "C3.Agent.FullName",               "Mapped", true),
                    F("Phone2",         "Representative Phone Number",            "Phone",         1, 0.94f, "inline-label",   "C3.Agent.Phone",                  "Mapped", false),
                    F("Date",           "Reporting period from",                  "Date",          1, 0.62f, "range-word",     null,                              "Manual", false),
                    F("Checkbox",       "Tax reporting",                          "Checkbox",      1, 0.93f, "checkbox-lexicon", null,                            "Manual", false),
                    F("Signature",      "Signature",                              "Signature",     1, 0.50f, "label-below",    null,                              "Manual", true),
                    F("Title",          "Title",                                  "Title",         1, 0.50f, "label-below",    null,                              "Manual", false),
                    F("PrintName",      "Print Name",                             "Text",          1, 0.50f, "label-below",    "C3.Employee.FullName",            "Mapped", true),
                    F("Date2",          "Date (signature)",                       "Date",          1, 0.50f, "label-below",    null,                              "Manual", true)
                };
            }

            // _rowY walks down the page so each field gets a plausible,
            // distinct page-relative rect (0..1) like the real engine emits.
            private static float _rowY = 0.10f;

            private static object F(string key, string label, string type, int page,
                                    float conf, string source,
                                    string suggestedTarget, string suggestedMode, bool required)
            {
                _rowY += 0.045f;
                if (_rowY > 0.92f) _rowY = 0.12f;

                return new
                {
                    Key = key,
                    Label = label,
                    Type = type,
                    Page = page,
                    Confidence = conf,
                    Source = source,
                    // Page-relative rect (0..1) — survives DPI/zoom, and is what
                    // the generation step multiplies by the real page size.
                    Rect = new
                    {
                        X = type == "Checkbox" ? 0.055f : 0.30f,
                        Y = (float)Math.Round(_rowY, 3),
                        W = type == "Checkbox" ? 0.018f : 0.60f,
                        H = 0.018f
                    },
                    NeedsReview = conf < 0.60f
                                  || source == "checkbox-lexicon"
                                  || source == "label-above-box"
                                  || source == "range-word",
                    SuggestedTarget = suggestedTarget,
                    SuggestedMode = suggestedMode,
                    Required = required
                };
            }

            public static string[] DataSourceCatalog()
            {
                return new[]
                {
                    "C3.Employee.FullName",
                    "C3.Employee.FirstName",
                    "C3.Employee.LastName",
                    "C3.Employee.SSN",
                    "C3.Employee.Address",
                    "C3.Employee.City",
                    "C3.Employee.State",
                    "C3.Employee.Zip",
                    "C3.Employee.Phone",
                    "C3.Employee.Email",
                    "C3.Agent.FullName",
                    "C3.Agent.Phone",
                    "C3.Agent.Email",
                    "C3.Company.Name",
                    "C3.Company.EIN",
                    "C3.Company.PayrollAccountNumber",
                    "C3.Company.Address",
                    "C3.Company.City",
                    "C3.Company.State",
                    "C3.Company.Zip",
                    "C3.Company.Phone",
                    "C3.Document.Date"
                };
            }
        }

        [WebMethod]
        public static string GenerateDocument(int Id)
        {
            // ── POC stub ────────────────────────────────────────────────────
            System.Diagnostics.Trace.TraceInformation(
                "[GenerateDocument] Simulated — id={0}", Id);

            return JsonConvert.SerializeObject(new
            {
                Success = true,
                RedirectUrl = (string)null
            });
        }

        // ─────────────────────────────────────────────────────────────────────
        // FLATTENER — maps model → JS property name contract.
        // Property names MUST match the key: values in Default.aspx JS.
        // ─────────────────────────────────────────────────────────────────────
        private static IEnumerable<object> FlattenRecords(IEnumerable<PoaFormModel> data)
        {
            return data.Select(x => (object)new
            {
                x.Id,
                x.Description,
                x.State,            // abbreviation (column + filter + select value)
                x.Active,
                x.MailCenterId,

                // Select fields: key name matches the editField key and the DTO
                // field name — all three are now consistently ...Id suffixed.
                ServiceTypeId = x.ServiceTypeId,
                PoaFormTypeId = x.PoaFormTypeId,
                FormUseId = x.FormUseId,
                PoaTypeId = x.PoaTypeId,
                SignatureTypeId = x.SignatureTypeId,
                ReturnTypeId = x.ReturnTypeId,
                OnlineRequirementId = x.OnlineRequirementId,

                x.ExtractionStatus,
                x.MappingStatus,
                x.DocumentReference,
                x.FileName,
                x.FileExtension,
                x.Notes,
                LastUpdated = x.LastUpdated.HasValue
                    ? x.LastUpdated.Value.ToString("MM/dd/yyyy hh:mm tt")
                    : "",
                // Display name of the last editor — populated by the server on
                // Insert/Update (never sent by the client / not on PoaFormDto).
                UpdatedBy = x.UpdatedBy ?? ""
            }).ToList();
        }

        // ─────────────────────────────────────────────────────────────────────
        // DTO received from the JS for Insert / Update calls.
        // Property names must match the editField keys in Default.aspx.
        // ─────────────────────────────────────────────────────────────────────
        public class PoaFormDto
        {
            public int Id { get; set; }
            public string Description { get; set; }
            public string State { get; set; }   // abbreviation → StateId on server
            public bool Active { get; set; }
            public int? MailCenterId { get; set; }

            // Foreign-key IDs sent directly from the combo boxes.
            public int? ServiceTypeId { get; set; }
            public int? PoaFormTypeId { get; set; }
            public int? FormUseId { get; set; }
            public int? PoaTypeId { get; set; }
            public int? SignatureTypeId { get; set; }
            public int? ReturnTypeId { get; set; }
            public int? OnlineRequirementId { get; set; }

            public string DocumentReference { get; set; }
            public string FileName { get; set; }
            public string FileExtension { get; set; }
            public string Notes { get; set; }
        }

        // ─────────────────────────────────────────────────────────────────────
        // FAKE SERVICE — delete when wiring the real IPoaFormsService.
        //
        // The lookup methods below mirror the real PoaFormsService signatures
        // exactly, so swapping to the real service is a 1-line change per call:
        //
        //   FakePoaFormsService.GetServiceTypes()  →  PoaFormsService.GetServiceTypes()
        //
        // Real service (from your repository) returns:
        //   GetServiceTypes()       → service_type            (service_type_id / _description)
        //   GetFormUses()           → poa_form_uses           (poa_form_use_id / _description)
        //   GetPoaTypes()           → poa_types               (poa_type_id / _description)
        //   GetSignatureTypes()     → poa_signature_types     (poa_signature_type_id / _description)
        //   GetOnlineRequirements() → poa_online_requirements (poa_online_requirement_id / _description)
        //   GetReturnTypes()        → poa_return_types        (poa_return_type_id / _description)
        //   GetStates()             → state_codes             (code / state)
        //   GetPoaFormTypes()       → poa_form_types          (poa_form_type_id / _description)
        //   GetMailCenters()        → mail_centers            (mail_center_id / _description)
        // ─────────────────────────────────────────────────────────────────────
        private static class FakePoaFormsService
        {
            // ── Lookup methods (combo box sources) ─────────────────────────────
            public static IEnumerable<LookupItem> GetServiceTypes() => new[]
            {
                new LookupItem { Id = 1, Name = "Full" },
                new LookupItem { Id = 2, Name = "Partial" },
                new LookupItem { Id = 3, Name = "Limited" }
            };

            public static IEnumerable<LookupItem> GetPoaFormTypes() => new[]
            {
                new LookupItem { Id = 1, Name = "POA" },
                new LookupItem { Id = 2, Name = "2848" },
                new LookupItem { Id = 3, Name = "8821" }
            };

            public static IEnumerable<LookupItem> GetFormUses() => new[]
            {
                new LookupItem { Id = 1, Name = "Filing" },
                new LookupItem { Id = 2, Name = "Representation" },
                new LookupItem { Id = 3, Name = "Both" }
            };

            public static IEnumerable<LookupItem> GetPoaTypes() => new[]
            {
                new LookupItem { Id = 1, Name = "Tax" },
                new LookupItem { Id = 2, Name = "Financial" },
                new LookupItem { Id = 3, Name = "Medical" }
            };

            public static IEnumerable<LookupItem> GetSignatureTypes() => new[]
            {
                new LookupItem { Id = 1, Name = "Digital" },
                new LookupItem { Id = 2, Name = "Electronic" },
                new LookupItem { Id = 3, Name = "Wet" }
            };

            public static IEnumerable<LookupItem> GetOnlineRequirements() => new[]
            {
                new LookupItem { Id = 1, Name = "None" },
                new LookupItem { Id = 2, Name = "Required" },
                new LookupItem { Id = 3, Name = "Optional" }
            };

            public static IEnumerable<LookupItem> GetReturnTypes() => new[]
            {
                new LookupItem { Id = 1, Name = "Mail" },
                new LookupItem { Id = 2, Name = "Fax" },
                new LookupItem { Id = 3, Name = "E-File" },
                new LookupItem { Id = 4, Name = "Portal" }
            };

            public static IEnumerable<LookupItem> GetMailCenters() => new[]
            {
                new LookupItem { Id = 3,  Name = "Mail Center 3" },
                new LookupItem { Id = 5,  Name = "Mail Center 5" },
                new LookupItem { Id = 6,  Name = "Mail Center 6" },
                new LookupItem { Id = 7,  Name = "Mail Center 7" },
                new LookupItem { Id = 8,  Name = "Mail Center 8" },
                new LookupItem { Id = 9,  Name = "Mail Center 9" },
                new LookupItem { Id = 10, Name = "Mail Center 10" },
                new LookupItem { Id = 11, Name = "Mail Center 11" },
                new LookupItem { Id = 12, Name = "Mail Center 12" }
            };

            // GetStates returns the state code as Id and the state name as Name.
            public static IEnumerable<LookupItem> GetStates()
            {
                var codes = "AL,AK,AZ,AR,CA,CO,CT,DE,FL,GA,HI,ID,IL,IN,IA,KS,KY,LA,ME,MD,MA,MI,MN,MS,MO,MT,NE,NV,NH,NJ,NM,NY,NC,ND,OH,OK,OR,PA,RI,SC,SD,TN,TX,UT,VT,VA,WA,WV,WI,WY"
                            .Split(',');
                return codes.Select(c => new LookupItem { Id = c, Name = c }).ToList();
            }

            // ── Stateful seed (cached once so POC mutations persist) ───────────
            private static readonly object SeedLock = new object();
            private static List<PoaFormModel> _seed;
            private static List<PoaFormModel> Seed
            {
                get
                {
                    lock (SeedLock)
                    {
                        if (_seed == null) _seed = GetSeedData();
                        return _seed;
                    }
                }
            }

            // ── Single-record helpers (mapping modal) ──────────────────────────
            public static PoaFormModel GetById(int id)
            {
                lock (SeedLock)
                {
                    return Seed.FirstOrDefault(f => f.Id == id);
                }
            }

            public static void UpdateExtractionStatus(int id, string status)
            {
                lock (SeedLock)
                {
                    var form = Seed.FirstOrDefault(f => f.Id == id);
                    if (form != null)
                    {
                        form.ExtractionStatus = status;
                        form.LastUpdated = DateTime.Now;
                        form.UpdatedBy = GetCurrentUserName();
                    }
                }
            }

            public static void UpdateMappingStatus(int id, string status)
            {
                lock (SeedLock)
                {
                    var form = Seed.FirstOrDefault(f => f.Id == id);
                    if (form != null)
                    {
                        form.MappingStatus = status;
                        form.LastUpdated = DateTime.Now;
                        form.UpdatedBy = GetCurrentUserName();
                    }
                }
            }

            // ── Grid data ──────────────────────────────────────────────────────
            public static List<PoaFormModel> GetAllForms(
                int itemsPerPage,
                int pageNumber,
                out int totalCount,
                string search = null,
                string filterState = null,
                string sortKey = null,
                string sortDir = null)
            {
                List<PoaFormModel> snapshot;
                lock (SeedLock)
                {
                    snapshot = Seed.ToList();   // stateful seed — mapping/status
                }                               // updates persist across calls
                var all = snapshot.AsEnumerable();

                if (!string.IsNullOrWhiteSpace(search))
                {
                    var s = search.ToLowerInvariant();
                    all = all.Where(r =>
                        (r.Description ?? "").ToLowerInvariant().Contains(s) ||
                        (r.State ?? "").ToLowerInvariant().Contains(s) ||
                        (r.ServiceType ?? "").ToLowerInvariant().Contains(s));
                }

                if (!string.IsNullOrWhiteSpace(filterState))
                    all = all.Where(r => r.State == filterState);

                if (!string.IsNullOrWhiteSpace(sortKey))
                {
                    bool desc = string.Equals(sortDir, "desc",
                                              StringComparison.OrdinalIgnoreCase);
                    if (sortKey == "Description")
                        all = desc ? all.OrderByDescending(r => r.Description) : all.OrderBy(r => r.Description);
                    else if (sortKey == "State")
                        all = desc ? all.OrderByDescending(r => r.State) : all.OrderBy(r => r.State);
                    else if (sortKey == "ExtractionStatus")
                        all = desc ? all.OrderByDescending(r => r.ExtractionStatus) : all.OrderBy(r => r.ExtractionStatus);
                    else if (sortKey == "MappingStatus")
                        all = desc ? all.OrderByDescending(r => r.MappingStatus) : all.OrderBy(r => r.MappingStatus);
                    else if (sortKey == "LastUpdated")
                        all = desc ? all.OrderByDescending(r => r.LastUpdated) : all.OrderBy(r => r.LastUpdated);
                    else if (sortKey == "UpdatedBy")
                        all = desc ? all.OrderByDescending(r => r.UpdatedBy) : all.OrderBy(r => r.UpdatedBy);
                    else
                        all = all.OrderBy(r => r.Id);
                }

                var list = all.ToList();
                totalCount = list.Count;
                return list
                    .Skip((pageNumber - 1) * itemsPerPage)
                    .Take(itemsPerPage)
                    .ToList();
            }

            private static List<PoaFormModel> GetSeedData()
            {
                return new List<PoaFormModel>
                {
                    new PoaFormModel { Id=1,  Description="Texas Individual POA",   State="TX", Active=true,  MailCenterId=10, ServiceType="Full",    FormType="POA",  FormUse="Filing",         PoaType="Tax",       SignatureType="Digital",    OnlineRequirement="None",     ReturnType="Mail",   ExtractionStatus="Completed",  MappingStatus="Mapped",     DocumentReference="REF-TX-001", FileName="tx_poa.pdf",         FileExtension=".pdf", Notes="",                       LastUpdated=new DateTime(2025,5,10,9,30,0),  UpdatedBy="developer" },
                    new PoaFormModel { Id=2,  Description="California Corp POA",    State="CA", Active=true,  MailCenterId=12, ServiceType="Full",    FormType="2848", FormUse="Representation", PoaType="Tax",       SignatureType="Electronic", OnlineRequirement="Required", ReturnType="E-File", ExtractionStatus="Completed",  MappingStatus="Partial",    DocumentReference="REF-CA-002", FileName="ca_corp_poa.pdf",    FileExtension=".pdf", Notes="Needs review",           LastUpdated=new DateTime(2025,4,22,14,15,0), UpdatedBy="akshara koti" },
                    new PoaFormModel { Id=3,  Description="Ohio Tax Authority POA", State="OH", Active=true,  MailCenterId=8,  ServiceType="Partial", FormType="POA",  FormUse="Both",           PoaType="Financial", SignatureType="Wet",        OnlineRequirement="Optional", ReturnType="Fax",    ExtractionStatus="In Progress",MappingStatus="Not Mapped", DocumentReference="REF-OH-003", FileName="oh_poa.pdf",         FileExtension=".pdf", Notes="",                       LastUpdated=new DateTime(2025,5,1,11,0,0),   UpdatedBy="james gambel" },
                    new PoaFormModel { Id=4,  Description="Texas Business POA",     State="TX", Active=false, MailCenterId=10, ServiceType="Limited", FormType="8821", FormUse="Filing",         PoaType="Tax",       SignatureType="Digital",    OnlineRequirement="None",     ReturnType="Portal", ExtractionStatus="Not Started",MappingStatus="Not Mapped", DocumentReference="REF-OH-003",           FileName="oh_poa.pdf",                   FileExtension=".pdf",     Notes="Pending upload",         LastUpdated=null,                            UpdatedBy=null },
                    new PoaFormModel { Id=5,  Description="California Estate POA",  State="CA", Active=true,  MailCenterId=12, ServiceType="Full",    FormType="POA",  FormUse="Filing",         PoaType="Medical",   SignatureType="Wet",        OnlineRequirement="None",     ReturnType="Mail",   ExtractionStatus="Error",      MappingStatus="Not Mapped", DocumentReference="REF-CA-005", FileName="ca_estate_poa.pdf",  FileExtension=".pdf", Notes="Re-extraction required", LastUpdated=new DateTime(2025,3,18,8,45,0),  UpdatedBy="developer" },
                    new PoaFormModel { Id=6,  Description="New York IRS POA",       State="NY", Active=true,  MailCenterId=5,  ServiceType="Full",    FormType="2848", FormUse="Representation", PoaType="Tax",       SignatureType="Electronic", OnlineRequirement="Required", ReturnType="E-File", ExtractionStatus="Completed",  MappingStatus="Mapped",     DocumentReference="REF-NY-006", FileName="ny_irs_poa.pdf",     FileExtension=".pdf", Notes="",                       LastUpdated=new DateTime(2025,5,9,16,20,0),  UpdatedBy="akshara koti" },
                    new PoaFormModel { Id=7,  Description="Florida Medicaid POA",   State="FL", Active=true,  MailCenterId=3,  ServiceType="Full",    FormType="POA",  FormUse="Both",           PoaType="Medical",   SignatureType="Digital",    OnlineRequirement="Optional", ReturnType="Mail",   ExtractionStatus="Not Started",MappingStatus="Not Mapped", DocumentReference="",           FileName="",                   FileExtension="",     Notes="",                       LastUpdated=null,                            UpdatedBy=null },
                    new PoaFormModel { Id=8,  Description="Ohio Revenue POA",       State="OH", Active=true,  MailCenterId=8,  ServiceType="Partial", FormType="POA",  FormUse="Filing",         PoaType="Tax",       SignatureType="Wet",        OnlineRequirement="None",     ReturnType="Fax",    ExtractionStatus="Completed",  MappingStatus="Partial",    DocumentReference="REF-OH-008", FileName="oh_rev_poa.pdf",     FileExtension=".pdf", Notes="",                       LastUpdated=new DateTime(2025,4,30,10,0,0),  UpdatedBy="james gambel" },
                    new PoaFormModel { Id=9,  Description="Georgia State Tax POA",  State="GA", Active=false, MailCenterId=7,  ServiceType="Full",    FormType="8821", FormUse="Filing",         PoaType="Tax",       SignatureType="Electronic", OnlineRequirement="None",     ReturnType="Portal", ExtractionStatus="Not Started",MappingStatus="Not Mapped", DocumentReference="",           FileName="",                   FileExtension="",     Notes="Waiting for approval",   LastUpdated=null,                            UpdatedBy=null },
                    new PoaFormModel { Id=10, Description="Michigan Business POA",  State="MI", Active=true,  MailCenterId=6,  ServiceType="Limited", FormType="POA",  FormUse="Representation", PoaType="Financial", SignatureType="Digital",    OnlineRequirement="Optional", ReturnType="Mail",   ExtractionStatus="In Progress",MappingStatus="Not Mapped", DocumentReference="REF-MI-010", FileName="mi_biz_poa.pdf",     FileExtension=".pdf", Notes="",                       LastUpdated=new DateTime(2025,5,5,13,10,0),  UpdatedBy="developer" },
                    new PoaFormModel { Id=11, Description="Washington State POA",   State="WA", Active=true,  MailCenterId=9,  ServiceType="Full",    FormType="POA",  FormUse="Filing",         PoaType="Tax",       SignatureType="Electronic", OnlineRequirement="Required", ReturnType="E-File", ExtractionStatus="Not Started",MappingStatus="Not Mapped", DocumentReference="",           FileName="",                   FileExtension="",     Notes="",                       LastUpdated=null,                            UpdatedBy=null },
                    new PoaFormModel { Id=12, Description="Illinois Corp Tax POA",  State="IL", Active=true,  MailCenterId=11, ServiceType="Full",    FormType="2848", FormUse="Both",           PoaType="Tax",       SignatureType="Digital",    OnlineRequirement="None",     ReturnType="Mail",   ExtractionStatus="Completed",  MappingStatus="Mapped",     DocumentReference="REF-IL-012", FileName="il_corp_poa.pdf",    FileExtension=".pdf", Notes="",                       LastUpdated=new DateTime(2025,5,8,7,55,0),   UpdatedBy="akshara koti" }
                };
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // LOOKUP ITEM — matches the real service's LookupItem { Id, Name }.
        // Id is object because most lookups use int FK ids while GetStates()
        // uses the string state code. In your real LookupItem this is whatever
        // type your framework declares.
        // ─────────────────────────────────────────────────────────────────────
        public class LookupItem
        {
            public object Id { get; set; }
            public string Name { get; set; }
        }

        // ─────────────────────────────────────────────────────────────────────
        // MODEL — delete and reference your real PoaFormModel when wiring up.
        //
        // In the POC the display strings (ServiceType="Full") are kept as-is in
        // the seed data, and the FK id properties below are COMPUTED from them
        // via the same lookup maps the JS uses.  In your real EF model these
        // would already be real columns (service_type_id, etc.) and you'd drop
        // the computed getters.
        // ─────────────────────────────────────────────────────────────────────
        public class PoaFormModel
        {
            public int Id { get; set; }
            public string Description { get; set; }
            public string State { get; set; }
            public bool Active { get; set; }
            public int? MailCenterId { get; set; }
            public string ServiceType { get; set; }
            public string FormType { get; set; }
            public string FormUse { get; set; }
            public string PoaType { get; set; }
            public string SignatureType { get; set; }
            public string OnlineRequirement { get; set; }
            public string ReturnType { get; set; }
            public string ExtractionStatus { get; set; }
            public string MappingStatus { get; set; }
            public string DocumentReference { get; set; }
            public string FileName { get; set; }
            public string FileExtension { get; set; }
            public string Notes { get; set; }
            public DateTime? LastUpdated { get; set; }
            public string UpdatedBy { get; set; }   // display name of last editor

            // ── Computed FK ids (POC only) ──────────────────────────────────
            // Map the display value → id using the same ordering as the JS
            // LOOKUPS object.  In real EF these are stored columns.
            public int? ServiceTypeId { get { return MapId(ServiceType, "Full", "Partial", "Limited"); } }
            public int? PoaFormTypeId { get { return MapId(FormType, "POA", "2848", "8821"); } }
            public int? FormUseId { get { return MapId(FormUse, "Filing", "Representation", "Both"); } }
            public int? PoaTypeId { get { return MapId(PoaType, "Tax", "Financial", "Medical"); } }
            public int? SignatureTypeId { get { return MapId(SignatureType, "Digital", "Electronic", "Wet"); } }
            public int? ReturnTypeId { get { return MapId(ReturnType, "Mail", "Fax", "E-File", "Portal"); } }
            public int? OnlineRequirementId { get { return MapId(OnlineRequirement, "None", "Required", "Optional"); } }

            private static int? MapId(string value, params string[] ordered)
            {
                if (string.IsNullOrEmpty(value)) return null;
                for (int i = 0; i < ordered.Length; i++)
                    if (string.Equals(ordered[i], value, StringComparison.OrdinalIgnoreCase))
                        return i + 1;   // ids are 1-based to match the JS LOOKUPS
                return null;
            }
        }
    }
}
