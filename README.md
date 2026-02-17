# Azure Databricks Secure Reference Architecture (SRA) - Terraform

<p align="center">
  <img src="https://i.postimg.cc/hP90xPqh/SRA-Screenshot.png" />
</p>

## Project Overview

The **Azure Databricks Secure Reference Architecture** with Terraform enables deployment of Databricks workspaces on Azure with security best practices. Using the official Databricks Terraform provider, environments are programmatically set up with hardened configurations modeled after security-conscious customers. The templates are built on [Databricks Security Best Practices](https://www.databricks.com/trust/security-features#best-practices), providing a strong, prescriptive foundation for secure deployments.

- **[Azure SRA](azure/)** — Hub-spoke network, Databricks workspace, Azure Firewall, Unity Catalog, Private Endpoints

## Project Support

The code in this project is provided **for exploration purposes only** and is **not formally supported** by Databricks under any Service Level Agreements (SLAs). It is provided **AS-IS**, without any warranties or guarantees.  

Please **do not submit support tickets** to Databricks for issues related to the use of this project.  

The source code provided is subject to the Databricks [LICENSE](https://github.com/databricks/terraform-databricks-sra/blob/main/LICENSE) . All third-party libraries included or referenced are subject to their respective licenses set forth in the project license.

Any issues or bugs found should be submitted as [GitHub Issues](https://github.com/databricks/terraform-databricks-sra/issues) on the project repository. While these will be reviewed as time permits, there are **no formal SLAs** for support.

## Point-in-Time Solution

The **Security Reference Architecture (SRA)** - Terraform Templates is designed as a point-in-time solution that captures security best practices at the time of each release. 

This project **does not** guarantee backward compatibility between versions; new releases are not drop-in replacements for existing codebases.
