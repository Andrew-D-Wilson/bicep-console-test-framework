/**********************************
  Bicep Template: Shared Types
  Author: Andrew Wilson
***********************************/

// ** User Defined Types and Constructors **
// *****************************************

// TYPE: Core Parameters
// *********************

@export()
@description('Core Parameters Definition for Bicep Templates')
@sealed()
type coreParams = {
  @description('Location to deploy resources to')
  location: string
  @description('Location Short Name for resource naming')
  locationShortName: string
  @description('Environment to deploy to')
  environment: string
  @description('Project Prefix for resource naming')
  projectPrefix: string
}

@export()
@description('Core Parameters Constructor')
func newCoreParams(
  location string,
  locationShortName string,
  environment string,
  projectPrefix string
) coreParams => {
  location: location
  locationShortName: locationShortName
  environment: environment
  projectPrefix: projectPrefix
}

// TYPES: APIM API Operation
// - API Operation Definition
// - Query Parameter
// - Template Parameter
// - Header
// - Response

@export()
@description('APIM API Operation Definition')
@sealed()
type apiOperationDefinition = {
  @minLength(1)
  @maxLength(80)
  @description('The resource name')
  name: string
  @description('Used to re-write the URL to the backend service')
  outboundUrlTemplate: string?
  @description('The operation policy name')
  operationPolicyName: string?
  @description('Properties of the Operation Contract')
  properties: {
    @minLength(1)
    @maxLength(300)
    @description('Operation Name.')
    displayName: string
    @description('A Valid HTTP Operation Method. Typical Http Methods like GET, PUT, POST but not limited by only them.')
    method: string
    @minLength(1)
    @maxLength(1000)
    @description('Relative URL template identifying the target resource for this operation. May include parameters. Example: /customers/{cid}/orders/{oid}/?date={date}')
    urlTemplate: string
    @maxLength(1000)
    @description('Description of the operation. May include HTML formatting tags.')
    description: string
    @description('Collection of URL template parameters.')
    templateParameters: templateParameter[]?
    @description('An entity containing request details.')
    request: {
      @description('Collection of operation request query parameters.')
      queryParameters: queryParameter[]?
      @description('Collection of operation request headers.')
      headers: header[]?
    }
    @description('Array of Operation responses.')
    responses: response[]?
  }
}

@export()
type queryParameter = {
  @description('Parameter name.')
  name: string
  @description('Parameter type.')
  type: string
  @description('Specifies whether parameter is required or not.')
  required: bool?
}

@export()
type templateParameter = {
  @description('Parameter name.')
  name: string
  @description('Parameter type.')
  type: string
  @description('Specifies whether parameter is required or not.')
  required: bool?
}

@export()
type header = {
  @description('Header name.')
  name: string
  @description('Header type.')
  type: string
  @description('Specifies whether header is required or not.')
  required: bool?
  @description('Header values.')
  values: string[]?
}

@export()
type response = {
  @description('Operation response HTTP status code.')
  statusCode: int
}

// APIM API Version Set
@export()
@sealed()
@description('Api VersionSet contract properties.')
type APIVersionSetProperties = {
  @description('Description of the Version Set')
  description: string
  @minLength(1)
  @maxLength(100)
  @description('Display Name of the Version Set')
  displayName: string
  @minLength(1)
  @maxLength(100)
  @description('Name of HTTP header parameter that indicates the API Version if versioningScheme is set to header.')
  versionHeaderName: string?
  @description('An value that determines where the API Version identifier will be located in a HTTP request.')
  versioningScheme: 'Header' | 'Query' | 'Segment'
  @minLength(1)
  @maxLength(100)
  @description('Name of query parameter that indicates the API Version if versioningScheme is set to query.')
  versionQueryName: string?
}
