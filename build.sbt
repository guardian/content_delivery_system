import NativePackagerHelper._

name := "content-delivery-system"

version := "1.0.0"

enablePlugins(RiffRaffArtifact, UniversalPlugin)

mappings in Universal := contentOf("CDS")

packageName in Universal := normalizedName.value

topLevelDirectory in Universal := Some(normalizedName.value)

riffRaffPackageType := (packageBin in Universal).value

riffRaffManifestProjectName := s"multimedia:${name.value}"

riffRaffBuildIdentifier :=  Option(System.getenv("CIRCLE_BUILD_NUM")).getOrElse("dev")

riffRaffUploadArtifactBucket := Option("riffraff-artifact")

riffRaffUploadManifestBucket := Option("riffraff-builds")

riffRaffManifestBranch := Option(System.getenv("CIRCLE_BRANCH")).getOrElse("dev")

//riffRaffArtifactResources ++= Seq(
//  riffRaffPackageType.value -> s"packages/${name.value}/${name.value}.zip"
//)