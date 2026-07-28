<%@ WebHandler Language="C#" Class="AccordionGridProject.DownloadDocument" %>

using System;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Web;

namespace AccordionGridProject
{
    /// <summary>
    /// POC download handler — file-system stand-in for the production blob
    /// fetch (mirrors GetXMFaxReceipt: blobName → stream → attachment).
    /// Usage: DownloadDocument.ashx?blobName={guid-or-ref}&fileName={name}
    /// </summary>
    public class DownloadDocument : IHttpHandler
    {
        public void ProcessRequest(HttpContext context)
        {
            try
            {
                string blobName = context.Request.QueryString["blobName"];
                string fileName = context.Request.QueryString["fileName"];

                if (string.IsNullOrWhiteSpace(blobName))
                {
                    context.Response.StatusCode = 400;
                    context.Response.Write("Missing blobName.");
                    return;
                }

                // Path-traversal guard: reference must be a bare name.
                if (blobName.IndexOfAny(new[] { '/', '\\' }) >= 0 ||
                    blobName.Contains(".."))
                {
                    context.Response.StatusCode = 400;
                    context.Response.Write("Invalid reference.");
                    return;
                }

                string folderSetting = ConfigurationManager.AppSettings["PoaUploadFolder"]
                                       ?? "~/App_Data/PoaUploads";
                string folder = context.Server.MapPath(folderSetting);

                // Reference may or may not include the extension.
                string path = Directory.Exists(folder)
                    ? Directory.GetFiles(folder, blobName + ".*").FirstOrDefault()
                      ?? Path.Combine(folder, blobName)
                    : null;

                if (path == null || !File.Exists(path))
                {
                    // POC seed rows reference documents that were never really
                    // uploaded — explain instead of a bare 404.
                    context.Response.StatusCode = 404;
                    context.Response.ContentType = "text/plain";
                    context.Response.Write(
                        "Document not found in the POC store (seed rows have no real files). " +
                        "Upload via Add New to test download end-to-end.");
                    return;
                }

                string downloadName = string.IsNullOrWhiteSpace(fileName)
                    ? Path.GetFileName(path)
                    : fileName;

                context.Response.ContentType = "application/pdf";
                context.Response.AddHeader("Content-Disposition",
                    "attachment; filename=\"" + downloadName.Replace("\"", "") + "\"");
                context.Response.TransmitFile(path);
            }
            finally
            {
                context.ApplicationInstance.CompleteRequest();   // not Response.End()
            }
        }

        public bool IsReusable { get { return true; } }
    }
}
