cbuffer VS_CONSTANT_BUFFER : register(b0)
{
	matrix mWorldViewProj;
	float4  vSomeVectorThatMayBeNeededByASpecificShader;
	float fSomeFloatThatMayBeNeededByASpecificShader;
	float fTime;
	float fSomeFloatThatMayBeNeededByASpecificShader2;
	float fSomeFloatThatMayBeNeededByASpecificShader3;
};
