# `frontend`

Public S3 static website hosting module.

## Owns

- public website bucket
- S3 website hosting configuration
- bootstrap `index.html` object for first-time infra deploys
- deployment destination for built frontend assets

## Dependencies

- deploy role ARN for the role that publishes frontend assets

## Public Access

The bucket is intentionally public. The module disables the bucket-level S3
public access block and attaches a bucket policy that allows anonymous
`s3:GetObject` access to objects.

S3 website hosting serves `index.html` as both the index document and error
document. This supports static single-page apps that need browser routes to
fall back to the root document.

S3 website endpoints are HTTP-only. Add CloudFront or another HTTPS-capable
front door outside this module if HTTPS, custom TLS, CDN caching, or path-based
API forwarding is needed.

## Deployment Notes

The deploy role can list the bucket and create, read, and delete objects under
it. Object ownership is bucket-owner-enforced, so uploads do not rely on ACLs.

## Key outputs

- website bucket name
- S3 website endpoint
- S3 website domain
- S3 website URL

Used by the frontend build and deploy workflow path.

The Terraform module uploads a bootstrap `index.html` so the website serves a
valid page before the built frontend assets are published. Later frontend
deploys replace that object with the real app bundle output, so Terraform
intentionally ignores live content and metadata drift on that bootstrap object
after creation.
