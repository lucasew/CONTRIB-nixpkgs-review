import argparse

from nixpkgs_review.github import GithubClient

from .utils import ensure_github_token, get_current_pr


def approve_command(args: argparse.Namespace) -> None:
    github_client = GithubClient(ensure_github_token(args.token))
    github_client.approve_pr(get_current_pr())
