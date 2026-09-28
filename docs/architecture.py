"""Architecture diagram for saranreddy/aws-terraform-remote-state-starter.

Verified against main @ 2c29ba1. Every node maps to bootstrap/*.tf, environments/*,
modules/simple-workload or .github/workflows/ci.yml.

Render:  pip install diagrams   (also needs Graphviz: apt install graphviz / brew install graphviz)
         python docs/architecture.py   ->  docs/architecture.png (written next to this script)
"""
import os

from diagrams import Cluster, Diagram, Edge, getdiagram
from diagrams.aws.database import DynamodbTable
from diagrams.aws.general import User, Users
from diagrams.aws.management import SystemsManagerParameterStore
from diagrams.aws.security import IAM as IAMIcon, IAMRole
from diagrams.aws.storage import SimpleStorageServiceS3Bucket
from diagrams.onprem.ci import GithubActions
from diagrams.onprem.iac import Terraform

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "architecture")  # -> architecture.png next to this script

FONT = "DejaVu Sans"
GRAPH = {
    "fontname": FONT, "fontsize": "34", "labelloc": "t", "pad": "0.4",
    "nodesep": "0.4", "ranksep": "1.0", "splines": "spline", "newrank": "true",
    "compound": "true",
}
NODE = {"fontname": FONT, "fontsize": "21", "imagepos": "tc"}
EDGE = {"fontname": FONT, "fontsize": "19", "color": "#555555",
        # enter/leave icons at mid-height so arrowheads never land on label text
        "tailport": "e", "headport": "w"}

# diagrams.Edge hard-codes a 13pt label font on every edge; raise it so edge labels stay
# readable when the PNG is scaled down to README width.
Edge._default_edge_attrs = {"fontcolor": "#2D3436", "fontname": FONT, "fontsize": "19"}


def box(bg, pen, style="rounded"):
    return {"bgcolor": bg, "pencolor": pen, "fontname": FONT, "fontsize": "21",
            "style": style, "labeljust": "l", "margin": "24"}


TF_BOX = box("#fff4e0", "#e66100")                  # deployed by Terraform
SUB_BOX = box("#fffaf2", "#e66100")                 # sub-group inside a Terraform box
RUN_BOX = box("#e8f1fb", "#1a5fb4")                 # created by scripts / CLI
EXEC_BOX = box("#f3eefa", "#613583")                # per execution / runtime
MANAGED_BOX = box("#f6f5f4", "#9a9996", "dashed")   # not created by this repo
ACCOUNT_BOX = box("#ffffff", "#232f3e")

FLOW = dict(color="#1a5fb4", fontcolor="#1a5fb4", penwidth="2.2")
IO = dict(color="#26a269", fontcolor="#1e7d4f", penwidth="1.8")
IAM = dict(color="#c01c28", fontcolor="#c01c28", style="dashed", penwidth="1.6", constraint="false")
AUX = dict(color="#8a8a8a", fontcolor="#5e5c64", style="dotted", penwidth="1.8")
SETUP = dict(color="#e66100", fontcolor="#c64600", style="dashed", penwidth="1.8")
MANUAL = dict(color="#26a269", fontcolor="#1e7d4f", style="dashed", penwidth="2.2")
FAIL = dict(color="#c01c28", fontcolor="#c01c28", penwidth="2.2")
OPT = dict(color="#b5835a", fontcolor="#8f5f3a", style="dashed", penwidth="1.8")
HIDDEN = dict(style="invis")
DOWN = dict(tailport="s", headport="n")
UP = dict(tailport="n", headport="s")


def same_rank(*nodes):
    getdiagram().dot.body.append("{rank=same; " + " ".join(f'"{n._id}";' for n in nodes) + "}")


with Diagram(
    "aws-terraform-remote-state-starter",
    filename=OUT, outformat="png", show=False, direction="LR",
    graph_attr=GRAPH, node_attr=NODE, edge_attr=EDGE,
):
    admin = User("Platform\nengineer")
    devs = Users("Developers")
    boot = Terraform("bootstrap/\n(local state)")

    with Cluster("GitHub Actions  (ci.yml)", graph_attr=box("#f6f5f4", "#24292f")) as gha:
        plan = GithubActions("plan x3 envs\n(on PR)")
        a_dev = GithubActions("apply dev\n(push to main)")
        a_stage = GithubActions("apply stage\n(GitHub env,\nreviewers)")
        a_prod = GithubActions("apply prod\n(GitHub env,\nreviewers)")

    with Cluster("AWS account  (default us-east-1)", graph_attr=ACCOUNT_BOX):
        with Cluster("Deployed by bootstrap Terraform", graph_attr=TF_BOX) as bootc:
            oidc = IAMIcon("GitHub OIDC\nprovider\n(optional,\ndefault on)")
            plan_role = IAMRole("github-plan role\n(read-only state)")
            apply_role = IAMRole("github-apply-<env>\nroles x3")
            state = SimpleStorageServiceS3Bucket("State bucket\nversioned, SSE-S3\nTLS-only\nold versions 90d")
            lock = DynamodbTable("Lock table\nterraform-state-lock")

        with Cluster("Per env x3  (applied by CI)",
                     graph_attr=EXEC_BOX):
            wl_bucket = SimpleStorageServiceS3Bucket("Workload bucket\n<project>-<env>-\nworkload-<suffix>")
            ssm = SystemsManagerParameterStore("SSM parameter\n/<project>/<env>/\nconfig")

    admin >> Edge(label="apply once", **SETUP) >> boot
    boot >> Edge(label="creates", lhead=bootc.name, **SETUP) >> oidc
    devs >> Edge(label="open PR", **FLOW) >> plan
    devs >> Edge(label="merge", **FLOW) >> a_dev
    same_rank(plan, a_dev, a_stage, a_prod)
    # flat edges are laid out bottom-to-top in LR, so draw them reversed (dir=back)
    a_stage << Edge(label="then", tailport="_", headport="_", **FLOW) << a_dev
    a_prod << Edge(label="then", tailport="_", headport="_", **FLOW) << a_stage

    a_dev >> Edge(label="OIDC token", ltail=gha.name, color="#c01c28", fontcolor="#c01c28",
                  style="dashed", penwidth="1.8") >> oidc
    oidc >> Edge(label="assume", **FLOW) >> plan_role
    oidc >> Edge(label="assume", **FLOW) >> apply_role
    plan_role >> Edge(label="read", **IO) >> state
    plan_role >> Edge(label="lock", **IO) >> lock
    apply_role >> Edge(label="rw <env>/ only", **IO) >> state
    apply_role >> Edge(label="lock", **IO) >> lock
    apply_role >> Edge(label="create", **FLOW) >> wl_bucket
    apply_role >> Edge(label="create", **FLOW) >> ssm
