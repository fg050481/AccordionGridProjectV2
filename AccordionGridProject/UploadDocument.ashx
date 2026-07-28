<%@ WebHandler Language="C#" Class="AccordionGridProject.UploadDocument" %>

using System;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Web;
using Newtonsoft.Json;

namespace AccordionGridProject
{
    /// <summary>
    /// POC upload handler. WebMethods cannot receive multipart/form-data, so
    /// uploads go through a Generic Handler — same pattern as production,
    /// where the stream goes to Azure Blob Storage instead of App_Data.
    /// Returns { guid } on success, { error } otherwise.
    /// </summary>
    public class UploadDocument : IHttpHandler
    {
        private static readonly string[] AllowedExtensions = { ".pdf" };
        private const long MaxBytes = 20L * 1024 * 1024;   // 20 MB

        public void ProcessRequest(HttpContext context)
        {
            context.Response.ContentType = "application/json";
            try
            {
                if (context.Request.Files.Count == 0)
                {
                    WriteError(context, "No file received.");
                    return;
                }

                HttpPostedFile file = context.Request.Files[0];
                string ext = Path.GetExtension(file.FileName ?? "").ToLowerInvariant();

                if (!AllowedExtensions.Contains(ext))
                {
                    WriteError(context, "Only PDF files are allowed.");
                    return;
                }
                if (file.ContentLength <= 0 || file.ContentLength > MaxBytes)
                {
                    WriteError(context, "File is empty or exceeds 20 MB.");
                    return;
                }

                string folderSetting = ConfigurationManager.AppSettings["PoaUploadFolder"]
                                       ?? "~/App_Data/PoaUploads";
                string folder = context.Server.MapPath(folderSetting);
                if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);

                // GUID is the document reference — never trust the client name.
                string guid = Guid.NewGuid().ToString("N");
                string safeName = guid + ext;
                file.SaveAs(Path.Combine(folder, safeName));

                context.Response.Write(JsonConvert.SerializeObject(new { guid = guid }));
            }
            catch (Exception ex)
            {
                WriteError(context, "Upload failed: " + ex.Message);
            }
            finally
            {
                context.ApplicationInstance.CompleteRequest();   // not Response.End()
            }
        }

        private static void WriteError(HttpContext context, string message)
        {
            context.Response.StatusCode = 400;
            context.Response.Write(JsonConvert.SerializeObject(new { error = message }));
        }

        public bool IsReusable { get { return true; } }
    }
}
